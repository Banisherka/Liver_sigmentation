export type UploadStatus = 'uploaded' | 'error' | 'cancelled';

export interface UploadFileView {
  id: number;
  order: number;
  name: string;
  size: number;
  status: UploadStatus;
}

