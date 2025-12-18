import { SegmentationTaskStatus } from './response-model.interface';

/**
 * Модель ответа после загрузки файла
 */
export class UploadFileResponse {
  constructor(
    public task_id: number,
    public ct_scan_id: number,
    public status: SegmentationTaskStatus,
    public message: string
  ) {}

  static fromApiResponse(data: any): UploadFileResponse {
    return new UploadFileResponse(
      data.task_id,
      data.ct_scan_id,
      data.status,
      data.message
    );
  }
}

