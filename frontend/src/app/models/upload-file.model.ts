export type UploadStatus = 'pending' | 'processing' | 'uploaded' | 'completed' | 'failed' | 'error' | 'cancelled';

export interface UploadFileView {
  id: number;
  order: number;
  name: string;
  size: number;
  status: UploadStatus;
  file?: File; // Оригинальный файл для загрузки
  taskId?: number; // ID задачи на сервере
  ctScanId?: number; // ID КТ-скана
}

