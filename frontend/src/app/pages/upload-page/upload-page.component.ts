import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { FileDropzoneComponent } from '../../components/file-dropzone/file-dropzone.component';
import { ButtonComponent } from '../../shared/ui/button/button.component';
import { UploadFileView, UploadStatus } from '../../models/upload-file.model';

@Component({
  selector: 'app-upload-page',
  standalone: true,
  imports: [CommonModule, ButtonComponent, FileDropzoneComponent],
  templateUrl: './upload-page.component.html',
  styleUrl: './upload-page.component.scss'
})
export class UploadPageComponent {
  files: UploadFileView[] = [];
  private counter = 1;

  handleFilesSelected(fileList: FileList) {
    const items = Array.from(fileList).map((file) => ({
      id: this.counter++,
      order: this.files.length + 1,
      name: file.name,
      size: file.size,
      status: 'uploaded' as UploadStatus
    }));
    this.files = [...this.files, ...items];
  }

  handleLaunch() {
    this.files = this.files.map((file) => ({
      ...file,
      status: this.pickStatus()
    }));
  }

  handleRemove(id: number) {
    this.files = this.files.filter((file) => file.id !== id).map((file, index) => ({
      ...file,
      order: index + 1
    }));
  }

  private pickStatus(): UploadStatus {
    const statuses: UploadStatus[] = ['uploaded', 'error', 'cancelled'];
    return statuses[Math.floor(Math.random() * statuses.length)];
  }
}

