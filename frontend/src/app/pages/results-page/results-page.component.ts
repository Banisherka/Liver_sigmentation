import { CommonModule } from '@angular/common';
import { Component, OnInit, ViewChild, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Segmentation3dViewerComponent } from '../../components/segmentation-3d-viewer/segmentation-3d-viewer.component';
import { SegmentationMetricsComponent } from '../../components/segmentation-metrics/segmentation-metrics.component';
import { SegmentationControlsComponent } from '../../components/segmentation-controls/segmentation-controls.component';
import { ApiService } from '../../services/api.service';
import { ErrorModalService } from '../../services/error-modal.service';
import { SegmentationResult } from '../../models/segmentation-result.model';
import { SegmentationTask } from '../../models/segmentation-task.model';

/**
 * Страница отображения результатов сегментации
 */
@Component({
  selector: 'app-results-page',
  standalone: true,
  imports: [
    CommonModule,
    Segmentation3dViewerComponent,
    SegmentationMetricsComponent,
    SegmentationControlsComponent
  ],
  templateUrl: './results-page.component.html',
  styleUrl: './results-page.component.scss'
})
export class ResultsPageComponent implements OnInit {
  taskId = signal<number | undefined>(undefined);
  segmentationResult = signal<SegmentationResult | undefined>(undefined);
  segmentationTask = signal<SegmentationTask | undefined>(undefined);
  loading = signal(true);
  error = signal<string | undefined>(undefined);

  // Состояние для 3D визуализации
  wireframeMode = signal(false);
  autoRotate = signal(false);
  opacity = signal(0.8);

  @ViewChild(Segmentation3dViewerComponent) viewerComponent?: Segmentation3dViewerComponent;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private apiService: ApiService,
    private errorModalService: ErrorModalService
  ) {}

  ngOnInit(): void {
    // Получаем ID задачи из параметров маршрута
    const taskIdParam = this.route.snapshot.paramMap.get('id');
    if (taskIdParam) {
      this.taskId.set(parseInt(taskIdParam, 10));
      this.loadSegmentationData();
    } else {
      this.showError('ID задачи не указан');
      this.router.navigate(['/']);
    }
  }

  /**
   * Загрузка данных сегментации
   */
  protected loadSegmentationData(): void {
    const taskIdValue = this.taskId();
    if (!taskIdValue) return;

    this.loading.set(true);
    this.error.set(undefined);

    // Загружаем детали задачи
    this.apiService.getSegmentationDetail(taskIdValue)
      .pipe(takeUntilDestroyed())
      .subscribe({
        next: (task) => {
          this.segmentationTask.set(task);

          // Если задача завершена, загружаем результаты
          if (task.status === 'completed') {
            this.loadSegmentationResult();
          } else if (task.status === 'failed') {
            this.loading.set(false);
            const errorMsg = task.error_message || 'Задача завершилась с ошибкой';
            this.error.set(errorMsg);
            this.showError(errorMsg);
          } else {
            // Задача еще обрабатывается
            this.loading.set(false);
            this.error.set('Задача еще обрабатывается. Пожалуйста, обновите страницу позже.');
          }
        },
        error: (error: Error) => {
          this.loading.set(false);
          const errorMsg = error.message || 'Ошибка при загрузке задачи';
          this.error.set(errorMsg);
          this.showError(errorMsg);
        }
      });
  }

  /**
   * Загрузка результатов сегментации
   */
  private loadSegmentationResult(): void {
    const taskIdValue = this.taskId();
    if (!taskIdValue) return;

    this.apiService.getSegmentationResult(taskIdValue)
      .pipe(takeUntilDestroyed())
      .subscribe({
        next: (result) => {
          this.segmentationResult.set(result);
          this.loading.set(false);
        },
        error: (error: Error) => {
          this.loading.set(false);
          const errorMsg = error.message || 'Ошибка при загрузке результатов';
          this.error.set(errorMsg);
          this.showError(errorMsg);
        }
      });
  }

  /**
   * Обработка сброса вида
   */
  onResetView(): void {
    if (this.viewerComponent) {
      this.viewerComponent.resetCamera();
    }
  }

  /**
   * Обработка переключения каркаса
   */
  onWireframeToggle(enabled: boolean): void {
    this.wireframeMode.set(enabled);
  }

  /**
   * Обработка переключения автовращения
   */
  onRotationToggle(enabled: boolean): void {
    this.autoRotate.set(enabled);
  }

  /**
   * Обработка изменения прозрачности
   */
  onOpacityChange(value: number): void {
    this.opacity.set(value);
    if (this.viewerComponent) {
      this.viewerComponent.updateOpacity(value);
    }
  }

  /**
   * Скачивание маски сегментации
   */
  onDownloadMask(): void {
    const taskIdValue = this.taskId();
    if (!taskIdValue) return;

    this.apiService.downloadMask(taskIdValue)
      .pipe(takeUntilDestroyed())
      .subscribe({
        next: (blob) => {
          // Создаем ссылку для скачивания
          const url = window.URL.createObjectURL(blob);
          const link = document.createElement('a');
          link.href = url;
          link.download = `mask_task_${taskIdValue}.dcm`;
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
          window.URL.revokeObjectURL(url);
        },
        error: (error: Error) => {
          this.showError(error.message || 'Ошибка при скачивании маски');
        }
      });
  }

  /**
   * Показ модального окна с ошибкой
   */
  private showError(message: string): void {
    this.errorModalService.showError(message)
      .pipe(takeUntilDestroyed())
      .subscribe();
  }

  /**
   * Возврат на главную страницу
   */
  goBack(): void {
    this.router.navigate(['/']);
  }
}

