import { SegmentationTaskStatus, SegmentationMetrics } from './response-model.interface';

/**
 * Модель результата сегментации
 */
export class SegmentationResult {
  constructor(
    public task_id: number,
    public status: SegmentationTaskStatus,
    public metrics: SegmentationMetrics,
    public summary: {
      dice?: number;
      iou?: number;
      volume_ml?: number;
      quality?: string;
      clinical_grade?: boolean;
    },
    public inference_time_ms?: number,
    public mask_file?: string,
    public contours?: any
  ) {}

  static fromApiResponse(data: any): SegmentationResult {
    return new SegmentationResult(
      data.task_id,
      data.status,
      data.metrics,
      data.summary,
      data.inference_time_ms,
      data.mask_file,
      data.contours
    );
  }
}

