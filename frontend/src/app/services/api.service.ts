import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { ApiResponse, UploadFileResponse, SegmentationTaskDetail, SegmentationTasksListResponse, SegmentationResultResponse } from '../models/response-model.interface';
import { UploadFileRequest, CreateSegmentationRequest, GetSegmentationsRequest } from '../models/request-model.interface';
import { SegmentationTask } from '../models/segmentation-task.model';
import { SegmentationResult } from '../models/segmentation-result.model';
import { UploadFileResponse as UploadFileResponseModel } from '../models/upload-file-response.model';
import { environment } from '../../environments/environment';

/**
 * Единый сервис для работы с API
 */
@Injectable({
  providedIn: 'root'
})
export class ApiService {
  constructor(private http: HttpClient) {}

  /**
   * Загрузка DICOM файла и создание задачи сегментации
   */
  uploadFile(request: UploadFileRequest): Observable<UploadFileResponseModel> {
    const formData = new FormData();
    formData.append('file', request.file);
    if (request.patient_id) {
      formData.append('patient_id', request.patient_id);
    }

    return this.http.post<ApiResponse<any>>(`${environment.apiUrl}/segmentation/upload`, formData).pipe(
      map(response => {
        if (!response.success || !response.data) {
          throw new Error(response.error || 'Failed to upload file');
        }
        return UploadFileResponseModel.fromApiResponse(response.data);
      }),
      catchError(this.handleError)
    );
  }

  /**
   * Создание задачи сегментации для существующего КТ-скана
   */
  createSegmentation(request: CreateSegmentationRequest): Observable<UploadFileResponseModel> {
    return this.http.post<ApiResponse<any>>(`${environment.apiUrl}/segmentations`, request).pipe(
      map(response => {
        if (!response.success || !response.data) {
          throw new Error(response.error || 'Failed to create segmentation');
        }
        return UploadFileResponseModel.fromApiResponse(response.data);
      }),
      catchError(this.handleError)
    );
  }

  /**
   * Получение списка задач сегментации
   */
  getSegmentations(request?: GetSegmentationsRequest): Observable<SegmentationTask[]> {
    const params: any = {};
    if (request?.limit) {
      params.limit = request.limit.toString();
    }

    return this.http.get<ApiResponse<SegmentationTasksListResponse>>(`${environment.apiUrl}/segmentations`, { params }).pipe(
      map(response => {
        if (!response.success || !response.data) {
          throw new Error(response.error || 'Failed to get segmentations');
        }
        // Преобразуем краткую информацию в полную для создания модели
        return response.data.tasks.map(task => SegmentationTask.fromApiResponse({
          id: task.id,
          ct_scan: {
            id: task.ct_scan_id,
            patient_id: '',
            modality: '',
            slice_count: 0
          },
          status: task.status,
          created_at: task.created_at,
          started_at: task.started_at,
          completed_at: task.completed_at,
          inference_time_ms: task.inference_time_ms
        }));
      }),
      catchError(this.handleError)
    );
  }

  /**
   * Получение детальной информации о задаче сегментации
   */
  getSegmentationDetail(id: number): Observable<SegmentationTask> {
    return this.http.get<ApiResponse<SegmentationTaskDetail>>(`${environment.apiUrl}/segmentations/${id}`).pipe(
      map(response => {
        if (!response.success || !response.data) {
          throw new Error(response.error || 'Failed to get segmentation detail');
        }
        return SegmentationTask.fromApiResponse(response.data);
      }),
      catchError(this.handleError)
    );
  }

  /**
   * Получение результатов сегментации с метриками
   */
  getSegmentationResult(id: number): Observable<SegmentationResult> {
    return this.http.get<ApiResponse<SegmentationResultResponse>>(`${environment.apiUrl}/segmentations/${id}/result`).pipe(
      map(response => {
        if (!response.success || !response.data) {
          throw new Error(response.error || 'Failed to get segmentation result');
        }
        return SegmentationResult.fromApiResponse(response.data);
      }),
      catchError(this.handleError)
    );
  }

  /**
   * Скачивание файла маски сегментации
   */
  downloadMask(id: number): Observable<Blob> {
    return this.http.get(`${environment.apiUrl}/segmentations/${id}/download_mask`, {
      responseType: 'blob'
    }).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Проверка работоспособности API
   */
  healthCheck(): Observable<any> {
    return this.http.get<ApiResponse<any>>(`${environment.apiUrl}/health`).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Обработка ошибок HTTP запросов
   */
  private handleError = (error: HttpErrorResponse | Error): Observable<never> => {
    let errorMessage = 'Произошла неизвестная ошибка';

    if (error instanceof HttpErrorResponse) {
      if (error.error instanceof ErrorEvent) {
        // Ошибка клиента
        errorMessage = `Ошибка сети: ${error.error.message}`;
      } else {
        // Ошибка сервера
        const apiError = error.error as ApiResponse<any>;
        errorMessage = apiError?.error || error.message || `Ошибка сервера: ${error.status} ${error.statusText}`;
      }
    } else {
      // Другая ошибка
      errorMessage = error.message || errorMessage;
    }

    return throwError(() => new Error(errorMessage));
  };
}

