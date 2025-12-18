import { Component, OnInit, OnDestroy, OnChanges, input, signal, ElementRef, ViewChild, AfterViewInit, SimpleChanges, effect } from '@angular/core';
import { CommonModule } from '@angular/common';

// Импорт Three.js
import * as THREE from 'three';

/**
 * Компонент для 3D визуализации результатов сегментации печени
 */
@Component({
  selector: 'app-segmentation-3d-viewer',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="viewer-container">
      <div #rendererContainer class="renderer-container"></div>
      @if (loading()) {
        <div class="viewer-overlay">
          <p>Загрузка 3D модели...</p>
        </div>
      }
    </div>
  `,
  styles: [`
    .viewer-container {
      position: relative;
      width: 100%;
      height: 100%;
      background: #1a1a1a;
      border-radius: 8px;
      overflow: hidden;
    }

    .renderer-container {
      width: 100%;
      height: 100%;
    }

    .viewer-overlay {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      background: rgba(0, 0, 0, 0.7);
      z-index: 10;
      color: #fff;
    }
  `]
})
export class Segmentation3dViewerComponent implements OnInit, AfterViewInit, OnDestroy, OnChanges {
  @ViewChild('rendererContainer', { static: false }) rendererContainer!: ElementRef<HTMLDivElement>;
  
  maskData = input<ArrayBuffer | number[] | Float32Array | undefined>(undefined);
  contours = input<any>(undefined);
  wireframeMode = input(false);
  autoRotate = input(false);
  opacity = input(0.8);

  private scene!: THREE.Scene;
  private camera!: THREE.PerspectiveCamera;
  private renderer!: THREE.WebGLRenderer;
  private mesh?: THREE.Mesh;
  private wireframeMesh?: THREE.LineSegments;
  loading = signal(false);
  private animationFrameId?: number;

  constructor() {
    // Эффект для обновления прозрачности при изменении сигнала
    effect(() => {
      const opacityValue = this.opacity();
      if (this.mesh && this.mesh.material instanceof THREE.MeshPhongMaterial) {
        this.mesh.material.opacity = opacityValue;
      }
    });

    // Эффект для обновления видимости каркаса
    effect(() => {
      this.updateWireframeVisibility();
    });

    // Эффект для автовращения
    effect(() => {
      // Логика автовращения обрабатывается в animate()
    });
  }

  ngOnInit(): void {}

  ngAfterViewInit(): void {
    this.initThreeJs();
    if (this.maskData() || this.contours()) {
      this.loadSegmentationData();
    }
  }

  ngOnDestroy(): void {
    this.cleanup();
  }

  /**
   * Инициализация Three.js сцены
   */
  private initThreeJs(): void {
    if (!this.rendererContainer) return;

    const container = this.rendererContainer.nativeElement;
    const width = container.clientWidth;
    const height = container.clientHeight;

    // Создание сцены
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x1a1a1a);

    // Создание камеры
    this.camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 1000);
    this.camera.position.set(0, 0, 5);

    // Создание рендерера
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setSize(width, height);
    this.renderer.setPixelRatio(window.devicePixelRatio);
    container.appendChild(this.renderer.domElement);

    // Добавление освещения
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
    this.scene.add(ambientLight);

    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
    directionalLight.position.set(5, 5, 5);
    this.scene.add(directionalLight);

    // Добавление сетки для ориентации
    const gridHelper = new THREE.GridHelper(10, 10, 0x444444, 0x222222);
    this.scene.add(gridHelper);

    // Добавление осей
    const axesHelper = new THREE.AxesHelper(3);
    this.scene.add(axesHelper);

    // Обработка изменения размера окна
    const resizeObserver = new ResizeObserver(() => {
      const newWidth = container.clientWidth;
      const newHeight = container.clientHeight;
      this.camera.aspect = newWidth / newHeight;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(newWidth, newHeight);
    });
    resizeObserver.observe(container);

    // Запуск анимации
    this.animate();
  }

  /**
   * Загрузка данных сегментации
   */
  loadSegmentationData(): void {
    this.loading.set(true);

    try {
      // Создание простой 3D модели печени из контуров или данных маски
      const contoursValue = this.contours();
      const maskDataValue = this.maskData();
      
      if (contoursValue) {
        this.createMeshFromContours(contoursValue);
      } else if (maskDataValue) {
        this.createMeshFromMask(maskDataValue);
      } else {
        // Создание демо-модели для примера
        this.createDemoMesh();
      }
    } catch (error) {
      console.error('Error loading segmentation data:', error);
    } finally {
      this.loading.set(false);
    }
  }

  /**
   * Создание меша из контуров
   */
  private createMeshFromContours(contours: any): void {
    // Если контуры есть, создаем геометрию из них
    // Это упрощенная версия - в реальности нужно обрабатывать структуру контуров
    const geometry = new THREE.BufferGeometry();
    
    // Здесь должна быть логика создания вершин из контуров
    // Для примера создаем простую геометрию
    this.createDemoMesh();
  }

  /**
   * Создание меша из данных маски
   */
  private createMeshFromMask(maskData: ArrayBuffer | number[] | Float32Array): void {
    // Преобразование данных маски в 3D геометрию
    // Это упрощенная версия - в реальности нужна обработка объемных данных
    this.createDemoMesh();
  }

  /**
   * Создание демо-меша печени (для примера)
   */
  private createDemoMesh(): void {
    // Удаляем предыдущий меш, если есть
    if (this.mesh) {
      this.scene.remove(this.mesh);
      this.mesh.geometry.dispose();
      if (this.mesh.material instanceof THREE.Material) {
        this.mesh.material.dispose();
      }
    }

    // Создаем геометрию, похожую на печень
    const geometry = new THREE.IcosahedronGeometry(1.5, 2);
    
    // Деформируем для более реалистичного вида
    const positionAttribute = geometry.attributes['position'];
    if (positionAttribute instanceof THREE.BufferAttribute) {
      for (let i = 0; i < positionAttribute.count; i++) {
        const x = positionAttribute.getX(i);
        const y = positionAttribute.getY(i);
        const z = positionAttribute.getZ(i);
        
        // Добавляем небольшую деформацию
        positionAttribute.setX(i, x * (1 + Math.sin(y * 2) * 0.2));
        positionAttribute.setY(i, y * (1 + Math.cos(x * 2) * 0.15));
        positionAttribute.setZ(i, z * (1 + Math.sin(x + y) * 0.1));
      }
      positionAttribute.needsUpdate = true;
    }
    geometry.computeVertexNormals();

    // Создаем материал с полупрозрачностью
    const material = new THREE.MeshPhongMaterial({
      color: 0x8b4513, // Коричневый цвет печени
      transparent: true,
      opacity: this.opacity(),
      side: THREE.DoubleSide,
      shininess: 30,
      wireframe: false
    });

    this.mesh = new THREE.Mesh(geometry, material);
    this.scene.add(this.mesh);

    // Добавляем каркас для лучшей визуализации
    const wireframe = new THREE.WireframeGeometry(geometry);
    const wireframeMaterial = new THREE.LineBasicMaterial({ 
      color: 0xffffff, 
      opacity: 0.1, 
      transparent: true 
    });
    this.wireframeMesh = new THREE.LineSegments(wireframe, wireframeMaterial);
    this.updateWireframeVisibility();
  }

  /**
   * Цикл анимации
   */
  private animate = (): void => {
    this.animationFrameId = requestAnimationFrame(this.animate);

    // Вращение модели (опционально)
    if (this.mesh && this.autoRotate()) {
      this.mesh.rotation.y += 0.005;
    }

    this.renderer.render(this.scene, this.camera);
  };

  /**
   * Очистка ресурсов
   */
  private cleanup(): void {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }

    if (this.mesh) {
      this.scene.remove(this.mesh);
      this.mesh.geometry.dispose();
      if (this.mesh.material instanceof THREE.Material) {
        this.mesh.material.dispose();
      }
    }

    if (this.wireframeMesh) {
      this.scene.remove(this.wireframeMesh);
      this.wireframeMesh.geometry.dispose();
      if (this.wireframeMesh.material instanceof THREE.Material) {
        this.wireframeMesh.material.dispose();
      }
    }

    if (this.renderer) {
      this.renderer.dispose();
      if (this.rendererContainer) {
        const container = this.rendererContainer.nativeElement;
        if (container.contains(this.renderer.domElement)) {
          container.removeChild(this.renderer.domElement);
        }
      }
    }
  }

  /**
   * Обновление видимости каркаса
   */
  updateWireframeVisibility(): void {
    if (this.wireframeMesh) {
      if (this.wireframeMode()) {
        if (!this.scene.children.includes(this.wireframeMesh)) {
          this.scene.add(this.wireframeMesh);
        }
      } else {
        if (this.scene.children.includes(this.wireframeMesh)) {
          this.scene.remove(this.wireframeMesh);
        }
      }
    }
  }

  /**
   * Обновление прозрачности (для обратной совместимости с методами родительского компонента)
   */
  updateOpacity(opacity: number): void {
    // Это больше не нужно, так как эффект автоматически обновляет прозрачность
    // Оставляем для обратной совместимости
  }

  /**
   * Сброс вида камеры
   */
  resetCamera(): void {
    if (this.camera) {
      this.camera.position.set(0, 0, 5);
      this.camera.lookAt(0, 0, 0);
    }
    if (this.mesh) {
      this.mesh.rotation.set(0, 0, 0);
    }
  }

  /**
   * Установить данные маски (для обратной совместимости)
   */
  setMaskData(data: ArrayBuffer | number[] | Float32Array): void {
    // С сигналами это не нужно, но оставляем для обратной совместимости
    this.loadSegmentationData();
  }

  /**
   * Установить контуры (для обратной совместимости)
   */
  setContours(contours: any): void {
    // С сигналами это не нужно, но оставляем для обратной совместимости
    this.loadSegmentationData();
  }

  /**
   * Обработка изменений входных параметров (для обратной совместимости)
   */
  ngOnChanges(changes: SimpleChanges): void {
    // С сигналами изменения обрабатываются через effect()
  }
}

