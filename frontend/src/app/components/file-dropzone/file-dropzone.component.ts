import { CommonModule } from '@angular/common';
import {
  Component,
  ElementRef,
  EventEmitter,
  HostListener,
  Input,
  Output
} from '@angular/core';
import { ButtonComponent } from '../../shared/ui/button/button.component';
import { UploadFileView } from '../../models/upload-file.model';

/**
 * Разрешенные форматы файлов для медицинских снимков
 */
const ALLOWED_FILE_TYPES = [
  'application/dicom',
  'application/x-dicom',
  'image/dicom',
  'image/x-dicom',
  // DICOM часто имеет расширение .dcm без MIME типа
  'application/octet-stream' // Для .dcm файлов
];

/**
 * Разрешенные расширения файлов
 */
const ALLOWED_EXTENSIONS = ['.dcm', '.dicom', '.jpg', '.jpeg', '.png', '.tiff', '.tif', '.bmp'];

@Component({
  selector: 'app-file-dropzone',
  standalone: true,
  imports: [CommonModule, ButtonComponent],
  templateUrl: './file-dropzone.component.html',
  styleUrl: './file-dropzone.component.scss'
})
export class FileDropzoneComponent {
  @Input() title = 'Файлы';
  @Input() files: UploadFileView[] = [];
  @Input() acceptedFileTypes = ALLOWED_EXTENSIONS.map(ext => ext.substring(1)).join(',');

  @Output() selectFiles = new EventEmitter<FileList>();
  @Output() filesDropped = new EventEmitter<FileList>();
  @Output() launch = new EventEmitter<void>();
  @Output() remove = new EventEmitter<number>();
  @Output() fileFilterError = new EventEmitter<string>();

  isDragging = false;

  constructor(private host: ElementRef<HTMLElement>) {}

  /**
   * Проверка формата файла
   */
  private isValidFileType(file: File): boolean {
    // Проверка по расширению
    const fileName = file.name.toLowerCase();
    const hasValidExtension = ALLOWED_EXTENSIONS.some(ext => fileName.endsWith(ext.toLowerCase()));
    
    // Проверка по MIME типу (если доступен)
    const hasValidMimeType = !file.type || ALLOWED_FILE_TYPES.includes(file.type) || 
                             file.type.startsWith('image/') ||
                             file.type === 'application/octet-stream';

    // Для DICOM файлов (обычно .dcm), разрешаем даже если MIME тип неизвестен
    if (fileName.endsWith('.dcm') || fileName.endsWith('.dicom')) {
      return true;
    }

    // Для изображений проверяем и расширение и MIME тип
    return hasValidExtension && hasValidMimeType;
  }

  /**
   * Фильтрация файлов по разрешенным форматам
   */
  private filterFiles(fileList: FileList): FileList {
    const validFiles: File[] = [];
    const invalidFiles: string[] = [];

    Array.from(fileList).forEach(file => {
      if (this.isValidFileType(file)) {
        validFiles.push(file);
      } else {
        invalidFiles.push(file.name);
      }
    });

    if (invalidFiles.length > 0) {
      this.fileFilterError.emit(
        `Следующие файлы не поддерживаются: ${invalidFiles.join(', ')}. ` +
        `Поддерживаемые форматы: ${ALLOWED_EXTENSIONS.join(', ')}`
      );
    }

    // Создаем новый FileList с отфильтрованными файлами
    const dataTransfer = new DataTransfer();
    validFiles.forEach(file => dataTransfer.items.add(file));
    return dataTransfer.files;
  }

  @HostListener('dragover', ['$event'])
  handleDragOver(event: DragEvent) {
    event.preventDefault();
    this.isDragging = true;
  }

  @HostListener('dragleave', ['$event'])
  handleDragLeave(event: DragEvent) {
    const nextTarget = event.relatedTarget as Node | null;
    if (!nextTarget || !this.host.nativeElement.contains(nextTarget)) {
      this.isDragging = false;
    }
  }

  @HostListener('drop', ['$event'])
  handleDrop(event: DragEvent) {
    event.preventDefault();
    this.isDragging = false;
    const files = event.dataTransfer?.files;
    if (files && files.length) {
      const filteredFiles = this.filterFiles(files);
      if (filteredFiles.length > 0) {
        this.filesDropped.emit(filteredFiles);
      }
    }
  }

  onFileInputChange(event: Event) {
    const files = (event.target as HTMLInputElement).files;
    if (files && files.length) {
      const filteredFiles = this.filterFiles(files);
      if (filteredFiles.length > 0) {
        this.selectFiles.emit(filteredFiles);
      }
    }
    (event.target as HTMLInputElement).value = '';
  }

  formatSize(size: number) {
    return `${(size / (1024 * 1024)).toFixed(1)} Мб`;
  }
}

