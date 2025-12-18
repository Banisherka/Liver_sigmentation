import { CommonModule } from '@angular/common';
import { Component, OnDestroy } from '@angular/core';
import { Subject, Subscription } from 'rxjs';
import { takeUntil } from 'rxjs/operators';
import { FileDropzoneComponent } from '../../components/file-dropzone/file-dropzone.component';
import { ButtonComponent } from '../../shared/ui/button/button.component';
import { UploadFileView, UploadStatus } from '../../models/upload-file.model';
import { ApiService } from '../../services/api.service';
import { ErrorModalService } from '../../services/error-modal.service';

@Component({
  selector: 'app-upload-page',
  standalone: true,
  imports: [CommonModule, ButtonComponent, FileDropzoneComponent],
  templateUrl: './upload-page.component.html',
  styleUrl: './upload-page.component.scss'
})
export class UploadPageComponent implements OnDestroy {
  files: UploadFileView[] = [];
  private counter = 1;
  private destroy$ = new Subject<void>();
  private subscriptions = new Set<Subscription>();

  constructor(
    private apiService: ApiService,
    private errorModalService: ErrorModalService
  ) {}

  handleFilesSelected(fileList: FileList) {
    const items = Array.from(fileList).map((file) => ({
      id: this.counter++,
      order: this.files.length + 1,
      name: file.name,
      size: file.size,
      status: 'pending' as UploadStatus,
      file: file
    }));
    this.files = [...this.files, ...items];
  }

  handleFileFilterError(message: string) {
    const subscription = this.errorModalService.showError(message)
      .pipe(takeUntil(this.destroy$))
      .subscribe();
    this.subscriptions.add(subscription);
  }

  handleLaunch() {
    // Загружаем только файлы со статусом pending
    const pendingFiles = this.files.filter(f => f.status === 'pending' && f.file);
    
    if (pendingFiles.length === 0) {
      const subscription = this.errorModalService.showError('Нет файлов для загрузки')
        .pipe(takeUntil(this.destroy$))
        .subscribe();
      this.subscriptions.add(subscription);
      return;
    }

    // Загружаем каждый файл
    pendingFiles.forEach(fileView => {
      if (!fileView.file) return;

      // Устанавливаем статус processing
      this.updateFileStatus(fileView.id, 'processing');

      const subscription = this.apiService.uploadFile({
        file: fileView.file
      })
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (response) => {
          // Обновляем файл с информацией о задаче
          const fileIndex = this.files.findIndex(f => f.id === fileView.id);
          if (fileIndex !== -1) {
            this.files[fileIndex] = {
              ...this.files[fileIndex],
              status: this.mapApiStatusToUploadStatus(response.status),
              taskId: response.task_id,
              ctScanId: response.ct_scan_id
            };
          }
        },
        error: (error: Error) => {
          // Обновляем статус на ошибку
          this.updateFileStatus(fileView.id, 'error');
          
          // Показываем модальное окно с ошибкой
          const errorSubscription = this.errorModalService.showError(error.message || 'Ошибка при загрузке файла')
            .pipe(takeUntil(this.destroy$))
            .subscribe();
          this.subscriptions.add(errorSubscription);
        }
      });
      
      this.subscriptions.add(subscription);
    });
  }

  handleRemove(id: number) {
    this.files = this.files.filter((file) => file.id !== id).map((file, index) => ({
      ...file,
      order: index + 1
    }));
  }

  private updateFileStatus(id: number, status: UploadStatus) {
    const fileIndex = this.files.findIndex(f => f.id === id);
    if (fileIndex !== -1) {
      this.files[fileIndex] = {
        ...this.files[fileIndex],
        status
      };
    }
  }

  private mapApiStatusToUploadStatus(apiStatus: string): UploadStatus {
    const statusMap: Record<string, UploadStatus> = {
      'pending': 'pending',
      'processing': 'processing',
      'completed': 'completed',
      'failed': 'failed'
    };
    return statusMap[apiStatus] || 'pending';
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
    
    // Отписываемся от всех подписок
    this.subscriptions.forEach(subscription => {
      if (subscription && !subscription.closed) {
        subscription.unsubscribe();
      }
    });
    this.subscriptions.clear();
  }
}

