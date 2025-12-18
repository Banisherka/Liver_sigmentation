/**
 * Интерфейс для запроса загрузки файла
 */
export interface UploadFileRequest {
  file: File;
  patient_id?: string;
}

/**
 * Интерфейс для запроса создания задачи сегментации
 */
export interface CreateSegmentationRequest {
  ct_scan_id: number;
}

/**
 * Интерфейс для запроса списка задач с параметрами пагинации
 */
export interface GetSegmentationsRequest {
  limit?: number;
}

