import { SegmentationTaskStatus, CtScanInfo, SegmentationResultSummary } from './response-model.interface';

/**
 * Модель задачи сегментации
 */
export class SegmentationTask {
  constructor(
    public id: number,
    public ct_scan: CtScanInfo,
    public status: SegmentationTaskStatus,
    public created_at: string,
    public started_at?: string,
    public completed_at?: string,
    public inference_time_ms?: number,
    public error_message?: string,
    public result?: SegmentationResultSummary
  ) {}

  static fromApiResponse(data: any): SegmentationTask {
    return new SegmentationTask(
      data.id,
      data.ct_scan,
      data.status,
      data.created_at,
      data.started_at,
      data.completed_at,
      data.inference_time_ms,
      data.error_message,
      data.result
    );
  }
}

