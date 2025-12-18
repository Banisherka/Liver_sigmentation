import { Routes } from '@angular/router';
import { UploadPageComponent } from './pages/upload-page/upload-page.component';
import { ResultsPageComponent } from './pages/results-page/results-page.component';

export const routes: Routes = [
  {
    path: '',
    component: UploadPageComponent
  },
  {
    path: 'results/:id',
    component: ResultsPageComponent
  }
];
