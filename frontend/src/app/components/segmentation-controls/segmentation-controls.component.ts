import { Component, output, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSliderModule } from '@angular/material/slider';
import { FormsModule } from '@angular/forms';

/**
 * Компонент управления 3D визуализацией
 */
@Component({
  selector: 'app-segmentation-controls',
  standalone: true,
  imports: [CommonModule, MatButtonModule, MatIconModule, MatSliderModule, FormsModule],
  template: `
    <div class="controls-container">
      <h4 class="controls-title">Управление просмотром</h4>
      
      <div class="controls-group">
        <button mat-icon-button (click)="resetView.emit()" title="Сбросить вид">
          <mat-icon>refresh</mat-icon>
        </button>
        <button mat-icon-button (click)="toggleWireframe()" [class.active]="wireframeMode()" title="Каркас">
          <mat-icon>grid_on</mat-icon>
        </button>
        <button mat-icon-button (click)="toggleRotation()" [class.active]="autoRotate()" title="Автовращение">
          <mat-icon>360</mat-icon>
        </button>
      </div>

      <div class="controls-group">
        <label>Прозрачность</label>
        <mat-slider
          [min]="0"
          [max]="1"
          [step]="0.1"
          [discrete]="true"
        >
          <input matSliderThumb [value]="opacity()" (valueChange)="onOpacityChange($event)">
        </mat-slider>
        <span class="value-label">{{ opacity() | number:'1.1-1' }}</span>
      </div>

      <div class="controls-group">
        <button mat-button (click)="downloadMask.emit()" class="download-button">
          <mat-icon>download</mat-icon>
          Скачать маску
        </button>
      </div>
    </div>
  `,
  styles: [`
    .controls-container {
      background: #2b2b2b;
      border-radius: 8px;
      padding: 1.5rem;
      color: #f5f5f5;
    }

    .controls-title {
      margin: 0 0 1rem 0;
      font-size: 1.125rem;
      font-weight: 600;
      color: #fff;
    }

    .controls-group {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      margin-bottom: 1rem;

      &:last-child {
        margin-bottom: 0;
      }

      label {
        min-width: 100px;
        font-size: 0.875rem;
        color: #aaa;
      }

      mat-slider {
        flex: 1;
      }

      .value-label {
        min-width: 40px;
        text-align: right;
        font-size: 0.875rem;
        color: #fff;
      }
    }

    button[mat-icon-button] {
      color: #aaa;
      transition: color 0.2s;

      &:hover {
        color: #fff;
        background: rgba(255, 255, 255, 0.1);
      }

      &.active {
        color: #4caf50;
      }
    }

    .download-button {
      width: 100%;
      margin-top: 0.5rem;
      color: #fff;
      background: #4caf50;

      &:hover {
        background: #45a049;
      }

      mat-icon {
        margin-right: 0.5rem;
      }
    }
  `]
})
export class SegmentationControlsComponent {
  resetView = output<void>();
  wireframeToggle = output<boolean>();
  rotationToggle = output<boolean>();
  opacityChange = output<number>();
  downloadMask = output<void>();

  wireframeMode = signal(false);
  autoRotate = signal(false);
  opacity = signal(0.8);

  toggleWireframe(): void {
    const newValue = !this.wireframeMode();
    this.wireframeMode.set(newValue);
    this.wireframeToggle.emit(newValue);
  }

  toggleRotation(): void {
    const newValue = !this.autoRotate();
    this.autoRotate.set(newValue);
    this.rotationToggle.emit(newValue);
  }

  onOpacityChange(value: number | null): void {
    if (value !== null) {
      this.opacity.set(value);
      this.opacityChange.emit(value);
    }
  }
}

