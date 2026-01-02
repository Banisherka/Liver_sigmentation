"""
Service for liver segmentation
"""
import json
import math
import random
from typing import Dict, Any, Optional
from sqlalchemy.orm import Session

from app.models.ct_scan import CtScan, CtScanStatus
from app.models.segmentation_task import SegmentationTask, SegmentationTaskStatus
from app.models.segmentation_result import SegmentationResult
from app.services.application_service import ApplicationService, ServiceResult
from app.config import get_settings

settings = get_settings()


class LiverSegmentationService(ApplicationService):
    """Service for liver segmentation"""
    
    def __init__(self, ct_scan: CtScan, db: Session = None):
        self.ct_scan = ct_scan
        self.db = db
        self.task: Optional[SegmentationTask] = None
        self.error = None
    
    def execute(self) -> ServiceResult:
        """Execute segmentation"""
        if not self.ct_scan:
            return self.failure("CT scan not found")
        
        if self.ct_scan.is_processed():
            return self.failure("CT scan already processed")
        
        try:
            # Create task
            self.task = self._create_segmentation_task()
            
            # Process segmentation
            self._process_segmentation()
            
            return self.success(self.task)
        except Exception as e:
            if self.task:
                self.task.mark_as_failed(str(e))
                self.db.commit()
            return self.failure(str(e))
    
    def _create_segmentation_task(self) -> SegmentationTask:
        """Create segmentation task"""
        task = SegmentationTask(
            ct_scan_id=self.ct_scan.id,
            status=SegmentationTaskStatus.PENDING
        )
        self.db.add(task)
        self.db.commit()
        self.db.refresh(task)
        return task
    
    def _process_segmentation(self):
        """Process segmentation"""
        # Mark as processing
        self.task.mark_as_processing()
        self.ct_scan.status = CtScanStatus.PROCESSING
        self.db.commit()
        
        # Prepare input data
        input_data = self._prepare_input_data()
        
        # Run inference
        inference_result = self._run_inference(input_data)
        
        # Create result
        self._create_result(inference_result)
        
        # Mark as completed
        self.task.mark_as_completed(inference_result.get("inference_time_ms"))
        self.ct_scan.status = CtScanStatus.COMPLETED
        self.db.commit()
    
    def _prepare_input_data(self) -> Dict[str, Any]:
        """Prepare input data for neural network"""
        return {
            "ct_scan_id": self.ct_scan.id,
            "patient_id": self.ct_scan.patient_id,
            "dicom_path": self.ct_scan.dicom_file if hasattr(self.ct_scan, 'dicom_file') else None,
            "slice_count": self.ct_scan.slice_count,
            "modality": self.ct_scan.modality
        }
    
    def _run_inference(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Run neural network inference"""
        # TODO: In production, call Python neural network service
        # For now, return mock data
        
        return {
            "mask_data": self._generate_mock_mask(),
            "contours": self._generate_mock_contours(),
            "metrics": self._calculate_mock_metrics(),
            "inference_time_ms": random.randint(5000, 15000)
        }
    
    def _create_result(self, inference_result: Dict[str, Any]):
        """Create segmentation result"""
        metrics = inference_result["metrics"]
        
        result = SegmentationResult(
            segmentation_task_id=self.task.id,
            dice_coefficient=metrics["dice"],
            iou_score=metrics["iou"],
            volume_ml=metrics["volume_ml"],
            metrics=metrics,
            contours=inference_result["contours"]
        )
        
        if inference_result.get("mask_data"):
            result.mask_file = inference_result["mask_data"].get("path")
        
        self.db.add(result)
        self.db.commit()
    
    def _generate_mock_mask(self) -> Dict[str, Any]:
        """Generate mock mask data"""
        return {
            "format": "nifti",
            "path": f"tmp/masks/mock_mask_{self.ct_scan.id}.nii.gz",
            "dimensions": [512, 512, self.ct_scan.slice_count or 100]
        }
    
    def _generate_mock_contours(self) -> Dict[str, Any]:
        """Generate mock contour data"""
        slice_count = min(self.ct_scan.slice_count or 100, 10)
        
        return {
            "format": "json",
            "slices": [
                {
                    "slice_index": i,
                    "contour_points": self._generate_random_contour_points()
                }
                for i in range(slice_count)
            ]
        }
    
    def _generate_random_contour_points(self) -> list:
        """Generate random contour points"""
        center_x = 256
        center_y = 256
        radius = 80 + random.randint(0, 40)
        
        points = []
        for i in range(36):
            angle = (i * 10) * math.pi / 180
            points.append({
                "x": round(center_x + radius * math.cos(angle), 2),
                "y": round(center_y + radius * math.sin(angle), 2)
            })
        
        return points
    
    def _calculate_mock_metrics(self) -> Dict[str, float]:
        """Calculate mock metrics"""
        return {
            "dice": round(0.90 + random.random() * 0.07, 4),
            "iou": round(0.89 + random.random() * 0.08, 4),
            "volume_ml": round(1200.0 + random.random() * 400.0, 2),
            "pixel_accuracy": round(0.95 + random.random() * 0.04, 4),
            "sensitivity": round(0.92 + random.random() * 0.06, 4),
            "specificity": round(0.96 + random.random() * 0.03, 4)
        }

