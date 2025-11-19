"""
Модуль нейронной сети для сегментации печени

Этот модуль предоставляет модель сегментации печени на основе архитектуры 3D U-Net
для анализа КТ-сканов с клинической точностью (Dice >= 0.90, IoU >= 0.90).

Основные компоненты:
- UNet3D: Архитектура 3D U-Net для объемной сегментации
- LiverSegmentationModel: Обертка для работы с моделью
- LiverSegmentationInference: Пайплайн инференса от DICOM до результатов
- DicomPreprocessor: Предобработка DICOM файлов
- Метрики: Расчет Dice, IoU и других метрик качества
"""

__version__ = '1.0.0'
__author__ = 'CT Liver Segmentation Team'

# Импорт основных компонентов
from .model import UNet3D, LiverSegmentationModel
from .inference import LiverSegmentationInference
from .preprocessing import DicomPreprocessor, normalize_hounsfield_units
from .metrics import calculate_dice, calculate_iou, calculate_all_metrics

__all__ = [
    'UNet3D',  # Архитектура 3D U-Net
    'LiverSegmentationModel',  # Обертка для работы с моделью
    'LiverSegmentationInference',  # Пайплайн инференса
    'DicomPreprocessor',  # Предобработка DICOM
    'normalize_hounsfield_units',  # Нормализация единиц Хаунсфилда
    'calculate_dice',  # Расчет Dice Coefficient
    'calculate_iou',  # Расчет IoU
    'calculate_all_metrics'  # Расчет всех метрик
]
