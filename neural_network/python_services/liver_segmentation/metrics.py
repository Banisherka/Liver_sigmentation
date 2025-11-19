"""
Метрики медицинской визуализации для оценки сегментации

Реализует клинические метрики:
- Dice Coefficient (коэффициент Соренсена-Дайса, F1 Score)
- IoU (Intersection over Union, индекс Жаккара)
- Sensitivity (чувствительность, Recall)
- Specificity (специфичность)
- Pixel Accuracy (точность пикселей)
- Объемные метрики (объем печени в мл)
"""

import numpy as np
from typing import Dict, Tuple, Optional


def calculate_dice(ground_truth: np.ndarray, prediction: np.ndarray, smooth: float = 1e-7) -> float:
    """
    Calculate Dice Coefficient (F1 Score)
    
    Dice = 2 * |A ∩ B| / (|A| + |B|)
    
    Args:
        ground_truth (np.ndarray): Ground truth binary mask
        prediction (np.ndarray): Predicted binary mask
        smooth (float): Smoothing factor to avoid division by zero
    
    Returns:
        float: Dice coefficient [0, 1]
    """
    # Ensure binary
    gt = (ground_truth > 0).astype(np.float32)
    pred = (prediction > 0).astype(np.float32)
    
    # Calculate intersection and sizes
    intersection = np.sum(gt * pred)
    gt_size = np.sum(gt)
    pred_size = np.sum(pred)
    
    # Dice formula
    dice = (2.0 * intersection + smooth) / (gt_size + pred_size + smooth)
    
    return float(dice)


def calculate_iou(ground_truth: np.ndarray, prediction: np.ndarray, smooth: float = 1e-7) -> float:
    """
    Calculate Intersection over Union (Jaccard Index)
    
    IoU = |A ∩ B| / |A ∪ B|
    
    Args:
        ground_truth (np.ndarray): Ground truth binary mask
        prediction (np.ndarray): Predicted binary mask
        smooth (float): Smoothing factor
    
    Returns:
        float: IoU score [0, 1]
    """
    # Ensure binary
    gt = (ground_truth > 0).astype(np.float32)
    pred = (prediction > 0).astype(np.float32)
    
    # Calculate intersection and union
    intersection = np.sum(gt * pred)
    union = np.sum(gt) + np.sum(pred) - intersection
    
    # IoU formula
    iou = (intersection + smooth) / (union + smooth)
    
    return float(iou)


def calculate_sensitivity(ground_truth: np.ndarray, prediction: np.ndarray, smooth: float = 1e-7) -> float:
    """
    Calculate Sensitivity (Recall, True Positive Rate)
    
    Sensitivity = TP / (TP + FN)
    
    Args:
        ground_truth (np.ndarray): Ground truth binary mask
        prediction (np.ndarray): Predicted binary mask
        smooth (float): Smoothing factor
    
    Returns:
        float: Sensitivity [0, 1]
    """
    gt = (ground_truth > 0).astype(np.float32)
    pred = (prediction > 0).astype(np.float32)
    
    true_positive = np.sum(gt * pred)
    false_negative = np.sum(gt * (1 - pred))
    
    sensitivity = (true_positive + smooth) / (true_positive + false_negative + smooth)
    
    return float(sensitivity)


def calculate_specificity(ground_truth: np.ndarray, prediction: np.ndarray, smooth: float = 1e-7) -> float:
    """
    Calculate Specificity (True Negative Rate)
    
    Specificity = TN / (TN + FP)
    
    Args:
        ground_truth (np.ndarray): Ground truth binary mask
        prediction (np.ndarray): Predicted binary mask
        smooth (float): Smoothing factor
    
    Returns:
        float: Specificity [0, 1]
    """
    gt = (ground_truth > 0).astype(np.float32)
    pred = (prediction > 0).astype(np.float32)
    
    true_negative = np.sum((1 - gt) * (1 - pred))
    false_positive = np.sum((1 - gt) * pred)
    
    specificity = (true_negative + smooth) / (true_negative + false_positive + smooth)
    
    return float(specificity)


def calculate_pixel_accuracy(ground_truth: np.ndarray, prediction: np.ndarray) -> float:
    """
    Calculate Pixel Accuracy
    
    Accuracy = (TP + TN) / Total
    
    Args:
        ground_truth (np.ndarray): Ground truth binary mask
        prediction (np.ndarray): Predicted binary mask
    
    Returns:
        float: Pixel accuracy [0, 1]
    """
    gt = (ground_truth > 0).astype(np.float32)
    pred = (prediction > 0).astype(np.float32)
    
    correct = np.sum(gt == pred)
    total = gt.size
    
    accuracy = correct / total
    
    return float(accuracy)


def calculate_volume(mask: np.ndarray, spacing: Tuple[float, float, float] = (1.0, 1.0, 1.0)) -> Dict[str, float]:
    """
    Calculate volume metrics from segmentation mask
    
    Args:
        mask (np.ndarray): Binary segmentation mask
        spacing (tuple): Voxel spacing (z, y, x) in mm
    
    Returns:
        dict: Volume metrics (mL, mm³, voxel count)
    """
    voxel_volume = np.prod(spacing)  # mm³
    voxel_count = np.sum(mask > 0)
    
    volume_mm3 = voxel_count * voxel_volume
    volume_ml = volume_mm3 / 1000.0
    
    return {
        'volume_ml': round(volume_ml, 2),
        'volume_mm3': round(volume_mm3, 2),
        'voxel_count': int(voxel_count)
    }


def calculate_hausdorff_distance(ground_truth: np.ndarray, prediction: np.ndarray) -> float:
    """
    Calculate Hausdorff Distance (95th percentile)
    
    Measures maximum surface distance between masks.
    
    Args:
        ground_truth (np.ndarray): Ground truth binary mask
        prediction (np.ndarray): Predicted binary mask
    
    Returns:
        float: Hausdorff distance in pixels
    """
    # TODO: Implement proper Hausdorff distance
    # Requires scipy.spatial.distance or similar
    # For now, return placeholder
    return 0.0


def calculate_all_metrics(ground_truth: np.ndarray, 
                         prediction: np.ndarray,
                         spacing: Tuple[float, float, float] = (1.0, 1.0, 1.0)) -> Dict:
    """
    Calculate all segmentation metrics
    
    Args:
        ground_truth (np.ndarray): Ground truth binary mask
        prediction (np.ndarray): Predicted binary mask
        spacing (tuple): Voxel spacing (z, y, x) in mm
    
    Returns:
        dict: All metrics
    """
    metrics = {
        'dice': round(calculate_dice(ground_truth, prediction), 6),
        'iou': round(calculate_iou(ground_truth, prediction), 6),
        'sensitivity': round(calculate_sensitivity(ground_truth, prediction), 6),
        'specificity': round(calculate_specificity(ground_truth, prediction), 6),
        'pixel_accuracy': round(calculate_pixel_accuracy(ground_truth, prediction), 6)
    }
    
    # Add volume metrics
    volume_metrics = calculate_volume(prediction, spacing)
    metrics.update(volume_metrics)
    
    # Add clinical assessment
    metrics['meets_clinical_standards'] = (
        metrics['dice'] >= 0.90 and metrics['iou'] >= 0.90
    )
    
    if metrics['dice'] >= 0.90:
        metrics['quality_grade'] = 'Excellent'
    elif metrics['dice'] >= 0.80:
        metrics['quality_grade'] = 'Good'
    elif metrics['dice'] >= 0.70:
        metrics['quality_grade'] = 'Fair'
    else:
        metrics['quality_grade'] = 'Poor'
    
    return metrics


def confusion_matrix(ground_truth: np.ndarray, prediction: np.ndarray) -> Dict[str, int]:
    """
    Calculate confusion matrix components
    
    Args:
        ground_truth (np.ndarray): Ground truth binary mask
        prediction (np.ndarray): Predicted binary mask
    
    Returns:
        dict: TP, TN, FP, FN counts
    """
    gt = (ground_truth > 0).astype(np.int32)
    pred = (prediction > 0).astype(np.int32)
    
    tp = np.sum((gt == 1) & (pred == 1))
    tn = np.sum((gt == 0) & (pred == 0))
    fp = np.sum((gt == 0) & (pred == 1))
    fn = np.sum((gt == 1) & (pred == 0))
    
    return {
        'true_positive': int(tp),
        'true_negative': int(tn),
        'false_positive': int(fp),
        'false_negative': int(fn)
    }


def print_metrics_report(metrics: Dict):
    """
    Print formatted metrics report
    
    Args:
        metrics (dict): Metrics dictionary
    """
    print("\n" + "="*60)
    print("LIVER SEGMENTATION METRICS REPORT")
    print("="*60)
    
    print("\n📊 Overlap Metrics:")
    print(f"  Dice Coefficient:     {metrics.get('dice', 0):.6f}")
    print(f"  IoU (Jaccard):        {metrics.get('iou', 0):.6f}")
    
    print("\n🎯 Classification Metrics:")
    print(f"  Sensitivity (Recall): {metrics.get('sensitivity', 0):.6f}")
    print(f"  Specificity:          {metrics.get('specificity', 0):.6f}")
    print(f"  Pixel Accuracy:       {metrics.get('pixel_accuracy', 0):.6f}")
    
    print("\n📏 Volume Metrics:")
    print(f"  Volume (mL):          {metrics.get('volume_ml', 0):.2f}")
    print(f"  Volume (mm³):         {metrics.get('volume_mm3', 0):.2f}")
    print(f"  Voxel Count:          {metrics.get('voxel_count', 0):,}")
    
    print("\n✅ Clinical Assessment:")
    print(f"  Quality Grade:        {metrics.get('quality_grade', 'N/A')}")
    print(f"  Meets Standards:      {metrics.get('meets_clinical_standards', False)}")
    
    print("="*60 + "\n")


if __name__ == '__main__':
    # Test metrics with synthetic data
    print("Testing segmentation metrics...")
    
    # Create synthetic masks
    shape = (50, 128, 128)
    
    # Ground truth: circular liver region
    ground_truth = np.zeros(shape, dtype=np.uint8)
    center = (shape[0]//2, shape[1]//2, shape[2]//2)
    radius = 30
    
    for z in range(shape[0]):
        for y in range(shape[1]):
            for x in range(shape[2]):
                dist = np.sqrt((z-center[0])**2 + (y-center[1])**2 + (x-center[2])**2)
                if dist <= radius:
                    ground_truth[z, y, x] = 1
    
    # Prediction: slightly offset and smaller
    prediction = np.zeros(shape, dtype=np.uint8)
    center_pred = (center[0]+2, center[1]+2, center[2]+2)
    radius_pred = 28
    
    for z in range(shape[0]):
        for y in range(shape[1]):
            for x in range(shape[2]):
                dist = np.sqrt((z-center_pred[0])**2 + (y-center_pred[1])**2 + (x-center_pred[2])**2)
                if dist <= radius_pred:
                    prediction[z, y, x] = 1
    
    # Calculate metrics
    metrics = calculate_all_metrics(ground_truth, prediction, spacing=(1.5, 1.0, 1.0))
    
    # Print report
    print_metrics_report(metrics)
    
    print("✓ Metrics calculation test successful!")
