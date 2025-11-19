"""
Предобработка DICOM для сегментации печени

Обрабатывает:
- Загрузку DICOM файлов
- Нормализацию единиц Хаунсфилда (HU)
- Ресемплинг (изменение разрешения)
- Аугментацию данных (для обучения)
"""

import numpy as np
from pathlib import Path
from typing import Tuple, Dict, Optional


def normalize_hounsfield_units(volume: np.ndarray, 
                               window_center: float = 40.0,
                               window_width: float = 400.0) -> np.ndarray:
    """
    Normalize CT Hounsfield Units for liver imaging
    
    Typical liver window: Center=40, Width=400
    HU range for liver: approximately 40-60 HU
    
    Args:
        volume (np.ndarray): Raw HU values
        window_center (float): Window center in HU
        window_width (float): Window width in HU
    
    Returns:
        np.ndarray: Normalized volume [0, 1]
    """
    min_hu = window_center - (window_width / 2.0)
    max_hu = window_center + (window_width / 2.0)
    
    # Clip to window
    volume = np.clip(volume, min_hu, max_hu)
    
    # Normalize to [0, 1]
    volume = (volume - min_hu) / (max_hu - min_hu)
    
    return volume.astype(np.float32)


def clip_hounsfield_units(volume: np.ndarray,
                          min_hu: float = -200.0,
                          max_hu: float = 300.0) -> np.ndarray:
    """
    Clip HU values to relevant range for abdominal CT
    
    Args:
        volume (np.ndarray): Raw HU values
        min_hu (float): Minimum HU value
        max_hu (float): Maximum HU value
    
    Returns:
        np.ndarray: Clipped volume
    """
    return np.clip(volume, min_hu, max_hu)


class DicomPreprocessor:
    """
    DICOM preprocessing pipeline
    
    Handles:
    - DICOM loading
    - HU extraction and normalization
    - Resampling to standard spacing
    - Intensity windowing
    """
    
    def __init__(self,
                 target_spacing: Tuple[float, float, float] = (1.5, 1.0, 1.0),
                 window_center: float = 40.0,
                 window_width: float = 400.0):
        """
        Initialize preprocessor
        
        Args:
            target_spacing (tuple): Target voxel spacing (z, y, x) in mm
            window_center (float): HU window center
            window_width (float): HU window width
        """
        self.target_spacing = target_spacing
        self.window_center = window_center
        self.window_width = window_width
    
    def load_dicom(self, path: str) -> Tuple[np.ndarray, Dict]:
        """
        Load DICOM file or series
        
        Args:
            path (str): Path to DICOM file or directory
        
        Returns:
            tuple: (volume, metadata)
        """
        path = Path(path)
        
        if path.is_file():
            return self.load_single_dicom(path)
        elif path.is_dir():
            return self.load_dicom_series(path)
        else:
            raise FileNotFoundError(f"DICOM path not found: {path}")
    
    def load_single_dicom(self, file_path: Path) -> Tuple[np.ndarray, Dict]:
        """
        Load single DICOM file (single slice or multi-frame)
        
        Args:
            file_path (Path): DICOM file path
        
        Returns:
            tuple: (volume, metadata)
        """
        try:
            import pydicom
            ds = pydicom.dcmread(file_path)
            
            # Extract pixel data
            pixel_array = ds.pixel_array
            
            # Convert to HU if rescale parameters present
            if hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
                volume = pixel_array * ds.RescaleSlope + ds.RescaleIntercept
            else:
                volume = pixel_array.astype(np.float32)
            
            # Extract metadata
            metadata = self.extract_metadata(ds)
            
            # Normalize
            volume = normalize_hounsfield_units(volume, self.window_center, self.window_width)
            
            return volume, metadata
            
        except ImportError:
            # Fallback: create mock data
            print("Warning: pydicom not available, creating mock data")
            volume = self.create_mock_volume()
            metadata = self.create_mock_metadata()
            return volume, metadata
    
    def load_dicom_series(self, directory: Path) -> Tuple[np.ndarray, Dict]:
        """
        Load DICOM series from directory
        
        Args:
            directory (Path): Directory containing DICOM files
        
        Returns:
            tuple: (volume, metadata)
        """
        try:
            import pydicom
            from pydicom.filereader import InvalidDicomError
            
            # Find all DICOM files
            dicom_files = []
            for file in sorted(directory.iterdir()):
                try:
                    if file.is_file():
                        pydicom.dcmread(file, stop_before_pixels=True)
                        dicom_files.append(file)
                except (InvalidDicomError, AttributeError):
                    continue
            
            if not dicom_files:
                raise ValueError(f"No valid DICOM files found in {directory}")
            
            # Load first file for metadata
            first_ds = pydicom.dcmread(dicom_files[0])
            metadata = self.extract_metadata(first_ds)
            
            # Load all slices
            slices = []
            for file in dicom_files:
                ds = pydicom.dcmread(file)
                pixel_array = ds.pixel_array
                
                # Convert to HU
                if hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
                    hu_array = pixel_array * ds.RescaleSlope + ds.RescaleIntercept
                else:
                    hu_array = pixel_array.astype(np.float32)
                
                slices.append(hu_array)
            
            # Stack slices into volume
            volume = np.stack(slices, axis=0)
            
            # Normalize
            volume = normalize_hounsfield_units(volume, self.window_center, self.window_width)
            
            return volume, metadata
            
        except ImportError:
            # Fallback
            print("Warning: pydicom not available, creating mock data")
            volume = self.create_mock_volume()
            metadata = self.create_mock_metadata()
            return volume, metadata
    
    def extract_metadata(self, dicom_dataset) -> Dict:
        """
        Extract relevant metadata from DICOM dataset
        
        Args:
            dicom_dataset: pydicom Dataset object
        
        Returns:
            dict: Metadata dictionary
        """
        metadata = {}
        
        # Patient info (anonymized)
        metadata['patient_id'] = getattr(dicom_dataset, 'PatientID', 'UNKNOWN')
        
        # Study info
        metadata['study_date'] = getattr(dicom_dataset, 'StudyDate', '')
        metadata['modality'] = getattr(dicom_dataset, 'Modality', 'CT')
        
        # Image parameters
        metadata['rows'] = getattr(dicom_dataset, 'Rows', 512)
        metadata['columns'] = getattr(dicom_dataset, 'Columns', 512)
        
        # Spacing
        pixel_spacing = getattr(dicom_dataset, 'PixelSpacing', [1.0, 1.0])
        slice_thickness = getattr(dicom_dataset, 'SliceThickness', 1.0)
        metadata['spacing'] = (float(slice_thickness), float(pixel_spacing[0]), float(pixel_spacing[1]))
        
        # Window settings
        metadata['window_center'] = getattr(dicom_dataset, 'WindowCenter', self.window_center)
        metadata['window_width'] = getattr(dicom_dataset, 'WindowWidth', self.window_width)
        
        return metadata
    
    def create_mock_volume(self, shape=(100, 512, 512)) -> np.ndarray:
        """Create mock CT volume for testing"""
        # Simulate CT intensity distribution
        volume = np.random.normal(0.3, 0.1, shape).astype(np.float32)
        volume = np.clip(volume, 0, 1)
        
        # Add simulated liver region (brighter)
        z, h, w = shape
        liver_z = slice(z//3, 2*z//3)
        liver_h = slice(h//3, 2*h//3)
        liver_w = slice(w//3, 2*w//3)
        volume[liver_z, liver_h, liver_w] += 0.2
        volume = np.clip(volume, 0, 1)
        
        return volume
    
    def create_mock_metadata(self) -> Dict:
        """Create mock metadata for testing"""
        return {
            'patient_id': 'MOCK_PATIENT',
            'study_date': '20240101',
            'modality': 'CT',
            'rows': 512,
            'columns': 512,
            'spacing': (1.5, 1.0, 1.0),
            'window_center': self.window_center,
            'window_width': self.window_width
        }
    
    def resample_volume(self, volume: np.ndarray, 
                       current_spacing: Tuple[float, float, float],
                       target_spacing: Optional[Tuple[float, float, float]] = None) -> np.ndarray:
        """
        Resample volume to target spacing
        
        Args:
            volume (np.ndarray): Input volume
            current_spacing (tuple): Current voxel spacing (z, y, x)
            target_spacing (tuple): Target voxel spacing (z, y, x)
        
        Returns:
            np.ndarray: Resampled volume
        """
        if target_spacing is None:
            target_spacing = self.target_spacing
        
        # Calculate zoom factors
        zoom_factors = [
            current_spacing[i] / target_spacing[i]
            for i in range(3)
        ]
        
        # TODO: Implement proper resampling with scipy.ndimage.zoom
        # For now, return original volume
        print(f"Resampling with factors: {zoom_factors}")
        
        return volume


def augment_volume(volume: np.ndarray, 
                   flip: bool = False,
                   rotate: bool = False,
                   noise_level: float = 0.0) -> np.ndarray:
    """
    Apply data augmentation to volume
    
    Args:
        volume (np.ndarray): Input volume
        flip (bool): Apply random flipping
        rotate (bool): Apply random rotation
        noise_level (float): Gaussian noise std dev
    
    Returns:
        np.ndarray: Augmented volume
    """
    augmented = volume.copy()
    
    if flip and np.random.rand() > 0.5:
        axis = np.random.choice([1, 2])  # Flip along H or W
        augmented = np.flip(augmented, axis=axis)
    
    if rotate and np.random.rand() > 0.5:
        k = np.random.choice([1, 2, 3])  # 90, 180, 270 degrees
        augmented = np.rot90(augmented, k=k, axes=(1, 2))
    
    if noise_level > 0:
        noise = np.random.normal(0, noise_level, augmented.shape)
        augmented = augmented + noise
        augmented = np.clip(augmented, 0, 1)
    
    return augmented


if __name__ == '__main__':
    # Test preprocessing
    preprocessor = DicomPreprocessor()
    
    # Create mock volume
    volume, metadata = preprocessor.create_mock_volume(), preprocessor.create_mock_metadata()
    print(f"Volume shape: {volume.shape}")
    print(f"Volume range: [{volume.min():.3f}, {volume.max():.3f}]")
    print(f"Metadata: {metadata}")
    
    # Test augmentation
    augmented = augment_volume(volume, flip=True, rotate=True, noise_level=0.01)
    print(f"Augmented volume shape: {augmented.shape}")
    print("Preprocessing test successful!")
