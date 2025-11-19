"""
Пайплайн инференса для сегментации печени

Обрабатывает полный цикл инференса от DICOM файла до результата сегментации,
включая предобработку, инференс модели и постобработку.

Рабочий процесс:
1. Загрузка и предобработка DICOM серии
2. Запуск инференса нейронной сети
3. Постобработка маски сегментации
4. Расчет метрик качества
5. Экспорт результатов
"""

import os
import json
import time
import numpy as np
from pathlib import Path
from typing import Dict, Tuple, Optional

try:
    import pydicom
    from pydicom import dcmread
    DICOM_AVAILABLE = True
except ImportError:
    DICOM_AVAILABLE = False
    print("Warning: pydicom not available. DICOM processing will be limited.")

from .model import LiverSegmentationModel, create_baseline_model
from .preprocessing import DicomPreprocessor, normalize_hounsfield_units
from .metrics import calculate_all_metrics


class LiverSegmentationInference:
    """
    Полный пайплайн инференса для сегментации печени
    
    Отвечает за:
    - Загрузку и предобработку DICOM файлов
    - Запуск инференса 3D U-Net модели
    - Постобработку маски сегментации
    - Расчет метрик качества (Dice, IoU, объем)
    - Извлечение контуров
    - Сохранение результатов
    
    Рабочий процесс:
    1. Загрузка и предобработка DICOM серии
    2. Запуск инференса нейронной сети
    3. Постобработка маски сегментации
    4. Расчет метрик качества
    5. Экспорт результатов
    """
    
    def __init__(self, model_path=None, device=None, output_dir='tmp/segmentation_results'):
        """
        Инициализация пайплайна инференса
        
        Параметры:
            model_path (str): Путь к весам модели (опционально)
            device (str): Устройство для выполнения ('cuda' или 'cpu')
            output_dir (str): Директория для сохранения результатов
        """
        self.model = create_baseline_model(pretrained=bool(model_path), device=device)
        self.preprocessor = DicomPreprocessor()
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"Inference pipeline initialized on {self.model.device_name}")
    
    def segment_from_dicom(self, dicom_path: str, ground_truth=None) -> Dict:
        """
        Выполнение сегментации из DICOM файла/директории
        
        Параметры:
            dicom_path (str): Путь к DICOM файлу или директории
            ground_truth (np.ndarray): Опциональная эталонная маска для расчета метрик
        
        Возвращает:
            dict: Результаты включая маску, метрики и метаданные
        """
        start_time = time.time()
        
        # Шаг 1: Загрузка и предобработка DICOM
        print(f"Loading DICOM from: {dicom_path}")
        volume, metadata = self.preprocessor.load_dicom(dicom_path)
        
        # Шаг 2: Запуск инференса нейронной сети
        print("Running inference...")
        inference_start = time.time()
        mask = self.model.predict(volume)  # Предсказание маски сегментации
        inference_time = int((time.time() - inference_start) * 1000)  # Время в миллисекундах
        
        # Шаг 3: Постобработка маски (удаление шума, заполнение дыр)
        mask = self.postprocess_mask(mask)
        
        # Шаг 4: Расчет метрик
        # Если есть эталонная маска - рассчитываем полные метрики (Dice, IoU и т.д.)
        # Иначе - только объемные метрики
        metrics = None
        if ground_truth is not None:
            metrics = calculate_all_metrics(ground_truth, mask)
        else:
            # Расчет только объемных метрик (объем печени)
            metrics = self.calculate_volume_metrics(mask, metadata)
        
        # Шаг 5: Извлечение контуров из 3D маски
        contours = self.extract_contours(mask)
        
        # Шаг 6: Сохранение результатов на диск
        result_id = self.generate_result_id()
        output_paths = self.save_results(result_id, mask, contours, metrics)
        
        total_time = int((time.time() - start_time) * 1000)  # Общее время выполнения
        
        return {
            'result_id': result_id,
            'mask': mask,
            'contours': contours,
            'metrics': metrics,
            'inference_time_ms': inference_time,
            'total_time_ms': total_time,
            'output_paths': output_paths,
            'metadata': metadata
        }
    
    def segment_from_numpy(self, volume: np.ndarray, spacing=(1.0, 1.0, 1.0)) -> Dict:
        """
        Perform segmentation from numpy array
        
        Args:
            volume (np.ndarray): Input CT volume
            spacing (tuple): Voxel spacing (z, y, x) in mm
        
        Returns:
            dict: Segmentation results
        """
        start_time = time.time()
        
        # Normalize volume
        volume = normalize_hounsfield_units(volume)
        
        # Run inference
        mask = self.model.predict(volume)
        mask = self.postprocess_mask(mask)
        
        # Calculate metrics
        metrics = self.calculate_volume_metrics(mask, {'spacing': spacing})
        contours = self.extract_contours(mask)
        
        inference_time = int((time.time() - start_time) * 1000)
        
        return {
            'mask': mask,
            'contours': contours,
            'metrics': metrics,
            'inference_time_ms': inference_time
        }
    
    def postprocess_mask(self, mask: np.ndarray, min_volume_voxels=1000) -> np.ndarray:
        """
        Постобработка маски сегментации
        
        Выполняет:
        - Удаление маленьких несвязанных компонентов
        - Заполнение дыр
        - Сглаживание границ
        
        Параметры:
            mask (np.ndarray): Сырая маска сегментации
            min_volume_voxels (int): Минимальный размер компонента для сохранения
        
        Возвращает:
            np.ndarray: Очищенная маска
        """
        # Сейчас: простое пороговое преобразование
        # В продакшене: использовать scipy.ndimage для морфологических операций
        binary_mask = (mask > 0.5).astype(np.uint8)
        
        # TODO: Реализовать анализ связанных компонентов
        # TODO: Реализовать заполнение дыр
        # TODO: Реализовать сглаживание границ
        
        return binary_mask
    
    def calculate_volume_metrics(self, mask: np.ndarray, metadata: Dict) -> Dict:
        """
        Расчет объемных метрик
        
        Вычисляет объем печени в миллилитрах на основе маски сегментации
        и размеров вокселей из метаданных DICOM.
        
        Параметры:
            mask (np.ndarray): Маска сегментации
            metadata (dict): Метаданные изображения включая spacing (размеры вокселей)
        
        Возвращает:
            dict: Объемные метрики (объем в мл, мм³, количество вокселей)
        """
        spacing = metadata.get('spacing', (1.0, 1.0, 1.0))  # Размеры вокселя (z, y, x) в мм
        voxel_volume = np.prod(spacing)  # Объем одного вокселя в мм³
        
        liver_voxels = np.sum(mask > 0)  # Количество вокселей печени
        volume_mm3 = liver_voxels * voxel_volume  # Объем в мм³
        volume_ml = volume_mm3 / 1000.0  # Конвертация в миллилитры
        
        return {
            'volume_ml': round(volume_ml, 2),  # Объем в миллилитрах
            'volume_mm3': round(volume_mm3, 2),  # Объем в кубических миллиметрах
            'voxel_count': int(liver_voxels),  # Количество вокселей печени
            'spacing': spacing  # Размеры вокселей
        }
    
    def extract_contours(self, mask: np.ndarray, num_slices=None) -> Dict:
        """
        Извлечение 2D контуров из 3D маски
        
        Извлекает контуры печени из каждого среза 3D маски для визуализации.
        
        Параметры:
            mask (np.ndarray): 3D маска сегментации [D, H, W]
            num_slices (int): Количество срезов для извлечения (по умолчанию: все)
        
        Возвращает:
            dict: Структура данных контуров в формате JSON
        """
        if num_slices is None:
            num_slices = mask.shape[0]
        
        contours = {
            'format': 'json',
            'slices': []
        }
        
        step = max(1, mask.shape[0] // num_slices)
        
        for i in range(0, mask.shape[0], step):
            if i >= mask.shape[0]:
                break
            
            slice_mask = mask[i]
            if np.sum(slice_mask) == 0:
                continue  # Skip empty slices
            
            # TODO: Реализовать правильное извлечение контуров используя cv2.findContours
            # Сейчас: упрощенное представление
            contours['slices'].append({
                'slice_index': int(i),
                'has_liver': bool(np.any(slice_mask)),
                'liver_area': int(np.sum(slice_mask))
            })
        
        return contours
    
    def save_results(self, result_id: str, mask: np.ndarray, 
                    contours: Dict, metrics: Dict) -> Dict:
        """
        Сохранение результатов сегментации на диск
        
        Сохраняет маску, контуры и метрики в отдельные файлы.
        
        Параметры:
            result_id (str): Уникальный идентификатор результата
            mask (np.ndarray): Маска сегментации
            contours (dict): Данные контуров
            metrics (dict): Метрики качества
        
        Возвращает:
            dict: Пути к сохраненным файлам
        """
        result_dir = self.output_dir / result_id
        result_dir.mkdir(exist_ok=True)
        
        paths = {}
        
        # Сохранение маски как numpy array
        mask_path = result_dir / 'mask.npy'
        np.save(mask_path, mask)
        paths['mask_npy'] = str(mask_path)
        
        # Сохранение контуров как JSON
        contours_path = result_dir / 'contours.json'
        with open(contours_path, 'w') as f:
            json.dump(contours, f, indent=2)
        paths['contours_json'] = str(contours_path)
        
        # Сохранение метрик как JSON
        metrics_path = result_dir / 'metrics.json'
        with open(metrics_path, 'w') as f:
            json.dump(metrics, f, indent=2)
        paths['metrics_json'] = str(metrics_path)
        
        print(f"Results saved to: {result_dir}")
        
        return paths
    
    def generate_result_id(self) -> str:
        """Генерация уникального ID результата"""
        import uuid
        return f"seg_{uuid.uuid4().hex[:12]}"


def main():
    """Интерфейс командной строки для инференса"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Liver Segmentation Inference')
    parser.add_argument('input', help='Path to DICOM file or directory')
    parser.add_argument('--model', help='Path to model weights')
    parser.add_argument('--device', default='cuda', help='Device (cuda/cpu)')
    parser.add_argument('--output', default='tmp/segmentation_results', help='Output directory')
    
    args = parser.parse_args()
    
    # Run inference
    pipeline = LiverSegmentationInference(
        model_path=args.model,
        device=args.device,
        output_dir=args.output
    )
    
    result = pipeline.segment_from_dicom(args.input)
    
    print("\n=== Segmentation Results ===")
    print(f"Result ID: {result['result_id']}")
    print(f"Inference Time: {result['inference_time_ms']} ms")
    if result['metrics']:
        print(f"Metrics: {json.dumps(result['metrics'], indent=2)}")
    print(f"Output: {result['output_paths']}")


if __name__ == '__main__':
    main()
