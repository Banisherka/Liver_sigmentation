import { Component, input, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { SegmentationResult } from '../../models/segmentation-result.model';

/**
 * Компонент для отображения метрик сегментации
 */
@Component({
  selector: 'app-segmentation-metrics',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="metrics-container">
      <h3 class="metrics-title">Метрики качества</h3>
      
      <div class="metrics-grid">
        <div class="metric-card">
          <div class="metric-label">Dice Coefficient</div>
          <div class="metric-value">{{ metricsData()?.dice | number:'1.3-3' }}</div>
          <div class="metric-description">Мера совпадения сегментации</div>
        </div>

        <div class="metric-card">
          <div class="metric-label">IoU Score</div>
          <div class="metric-value">{{ metricsData()?.iou | number:'1.3-3' }}</div>
          <div class="metric-description">Intersection over Union</div>
        </div>

        <div class="metric-card">
          <div class="metric-label">Объем печени</div>
          <div class="metric-value">{{ metricsData()?.volume_ml | number:'1.2-2' }} мл</div>
          <div class="metric-description">Объем сегментированной печени</div>
        </div>

        <div class="metric-card">
          <div class="metric-label">Оценка качества</div>
          <div class="metric-value" [ngClass]="qualityClass()">
            {{ metricsData()?.quality_grade }}
          </div>
          <div class="metric-description">{{ qualityDescription() }}</div>
        </div>

        <div class="metric-card full-width">
          <div class="metric-label">Соответствие клиническим стандартам</div>
          <div class="metric-value" [ngClass]="meetsClinicalStandards() ? 'positive' : 'negative'">
            {{ meetsClinicalStandards() ? '✓ Соответствует' : '✗ Не соответствует' }}
          </div>
          <div class="metric-description">
            {{ meetsClinicalStandards()
              ? 'Результаты подходят для клинического использования' 
              : 'Требуется улучшение качества сегментации' }}
          </div>
        </div>
      </div>

      @if (inferenceTimeMs()) {
        <div class="inference-info">
          <p>Время обработки: {{ inferenceTimeMs() }} мс</p>
        </div>
      }
    </div>
  `,
  styles: [`
    .metrics-container {
      background: #2b2b2b;
      border-radius: 8px;
      padding: 1.5rem;
      color: #f5f5f5;
    }

    .metrics-title {
      margin: 0 0 1.5rem 0;
      font-size: 1.5rem;
      font-weight: 600;
      color: #fff;
    }

    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 1rem;
    }

    .metric-card {
      background: #1a1a1a;
      border-radius: 6px;
      padding: 1rem;
      border: 1px solid #3a3a3a;
      transition: border-color 0.2s;

      &:hover {
        border-color: #5a5a5a;
      }

      &.full-width {
        grid-column: 1 / -1;
      }
    }

    .metric-label {
      font-size: 0.875rem;
      color: #aaa;
      margin-bottom: 0.5rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .metric-value {
      font-size: 1.75rem;
      font-weight: 600;
      color: #fff;
      margin-bottom: 0.5rem;

      &.positive {
        color: #4caf50;
      }

      &.negative {
        color: #f44336;
      }

      &.excellent {
        color: #4caf50;
      }

      &.good {
        color: #8bc34a;
      }

      &.fair {
        color: #ff9800;
      }

      &.poor {
        color: #f44336;
      }
    }

    .metric-description {
      font-size: 0.75rem;
      color: #888;
      line-height: 1.4;
    }

    .inference-info {
      margin-top: 1.5rem;
      padding-top: 1.5rem;
      border-top: 1px solid #3a3a3a;
      font-size: 0.875rem;
      color: #aaa;
    }
  `]
})
export class SegmentationMetricsComponent {
  metrics = input<SegmentationResult | undefined>();

  metricsData = computed(() => this.metrics()?.metrics);
  inferenceTimeMs = computed(() => this.metrics()?.inference_time_ms);

  meetsClinicalStandards = computed(() => this.metricsData()?.meets_clinical_standards ?? false);

  qualityClass = computed(() => {
    const grade = this.metricsData()?.quality_grade?.toLowerCase();
    switch (grade) {
      case 'excellent': return 'excellent';
      case 'good': return 'good';
      case 'fair': return 'fair';
      case 'poor': return 'poor';
      default: return '';
    }
  });

  qualityDescription = computed(() => {
    const grade = this.metricsData()?.quality_grade?.toLowerCase();
    switch (grade) {
      case 'excellent':
        return 'Отличное качество сегментации (≥0.90)';
      case 'good':
        return 'Хорошее качество (≥0.80)';
      case 'fair':
        return 'Удовлетворительное качество (≥0.70)';
      case 'poor':
        return 'Низкое качество (<0.70)';
      default:
        return 'Оценка недоступна';
    }
  });
}

