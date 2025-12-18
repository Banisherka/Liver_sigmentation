import { Injectable } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { ErrorModalComponent } from '../shared/ui/error-modal/error-modal.component';
import { Observable } from 'rxjs';

/**
 * Сервис для отображения модальных окон с ошибками
 */
@Injectable({
  providedIn: 'root'
})
export class ErrorModalService {
  constructor(private dialog: MatDialog) {}

  /**
   * Показать модальное окно с ошибкой
   */
  showError(message: string): Observable<boolean> {
    return this.dialog.open(ErrorModalComponent, {
      width: '400px',
      data: { message }
    }).afterClosed();
  }
}

