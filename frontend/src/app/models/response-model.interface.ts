/**
 * Базовый интерфейс ответа API
 */
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

/**
 * Интерфейс ответа после загрузки файла
 */
export interface UploadFileResponse {
  task_id: number;
  ct_scan_id: number;
  status: SegmentationTaskStatus;
  message: string;
}

/**
 * Статусы задачи сегментации
 */
export type SegmentationTaskStatus = 'pending' | 'processing' | 'completed' | 'failed';

/**
 * Интерфейс краткой информации о задаче
 */
export interface SegmentationTaskSummary {
  id: number;
  ct_scan_id: number;
  status: SegmentationTaskStatus;
  created_at: string;
  started_at?: string;
  completed_at?: string;
  inference_time_ms?: number;
  has_result: boolean;
}

/**
 * Интерфейс списка задач
 */
export interface SegmentationTasksListResponse {
  tasks: SegmentationTaskSummary[];
}

/**
 * Интерфейс информации о КТ-скане
 */
export interface CtScanInfo {
  id: number;
  patient_id: string;
  study_date?: string;
  modality: string;
  slice_count: number;
}

/**
 * Интерфейс краткой информации о результате
 */
export interface SegmentationResultSummary {
  dice_coefficient?: number;
  iou_score?: number;
  volume_ml?: number;
  quality_grade?: string;
  meets_clinical_standards?: boolean;
}

/**
 * Интерфейс детальной информации о задаче
 */
export interface SegmentationTaskDetail {
  id: number;
  ct_scan: CtScanInfo;
  status: SegmentationTaskStatus;
  created_at: string;
  started_at?: string;
  completed_at?: string;
  inference_time_ms?: number;
  error_message?: string;
  result?: SegmentationResultSummary;
}

/**
 * Интерфейс метрик сегментации
 */
export interface SegmentationMetrics {
  dice: number;
  iou: number;
  volume_ml: number;
  quality_grade: string;
  meets_clinical_standards: boolean;
}

/**
 * Интерфейс результатов сегментации
 */
export interface SegmentationResultResponse {
  task_id: number;
  status: SegmentationTaskStatus;
  inference_time_ms?: number;
  mask_file?: string;
  contours?: any;
  metrics: SegmentationMetrics;
  summary: {
    dice?: number;
    iou?: number;
    volume_ml?: number;
    quality?: string;
    clinical_grade?: boolean;
  };
}

