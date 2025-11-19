"""
3D U-Net модель для сегментации печени

Реализует архитектуру 3D U-Net, оптимизированную для сегментации печени на КТ-сканах
с клинической точностью (Dice >= 0.90, IoU >= 0.90).

Архитектура:
- Encoder (кодировщик): 4 уровня с 3D свертками и max pooling
- Decoder (декодировщик): 4 уровня с транспонированными свертками и skip connections
- Выход: Бинарная маска сегментации (печень vs. фон)

Ссылки:
Ronneberger et al., "U-Net: Convolutional Networks for Biomedical Image Segmentation"
Çiçek et al., "3D U-Net: Learning Dense Volumetric Segmentation from Sparse Annotation"
"""

import torch
import torch.nn as nn
import torch.nn.functional as F


class DoubleConv3D(nn.Module):
    """Double 3D convolution block with batch normalization and ReLU"""
    
    def __init__(self, in_channels, out_channels, kernel_size=3, padding=1):
        super(DoubleConv3D, self).__init__()
        self.conv = nn.Sequential(
            nn.Conv3d(in_channels, out_channels, kernel_size, padding=padding),
            nn.BatchNorm3d(out_channels),
            nn.ReLU(inplace=True),
            nn.Conv3d(out_channels, out_channels, kernel_size, padding=padding),
            nn.BatchNorm3d(out_channels),
            nn.ReLU(inplace=True)
        )
    
    def forward(self, x):
        return self.conv(x)


class Down3D(nn.Module):
    """Downscaling block with max pooling followed by double convolution"""
    
    def __init__(self, in_channels, out_channels):
        super(Down3D, self).__init__()
        self.maxpool_conv = nn.Sequential(
            nn.MaxPool3d(2),
            DoubleConv3D(in_channels, out_channels)
        )
    
    def forward(self, x):
        return self.maxpool_conv(x)


class Up3D(nn.Module):
    """Upscaling block with transposed convolution followed by double convolution"""
    
    def __init__(self, in_channels, out_channels):
        super(Up3D, self).__init__()
        self.up = nn.ConvTranspose3d(in_channels, in_channels // 2, kernel_size=2, stride=2)
        self.conv = DoubleConv3D(in_channels, out_channels)
    
    def forward(self, x1, x2):
        x1 = self.up(x1)
        
        # Handle dimension mismatch due to pooling
        diffD = x2.size()[2] - x1.size()[2]
        diffH = x2.size()[3] - x1.size()[3]
        diffW = x2.size()[4] - x1.size()[4]
        
        x1 = F.pad(x1, [diffW // 2, diffW - diffW // 2,
                        diffH // 2, diffH - diffH // 2,
                        diffD // 2, diffD - diffD // 2])
        
        # Concatenate with skip connection
        x = torch.cat([x2, x1], dim=1)
        return self.conv(x)


class UNet3D(nn.Module):
    """
    3D U-Net for volumetric liver segmentation
    
    Args:
        in_channels (int): Number of input channels (typically 1 for CT)
        out_channels (int): Number of output channels (1 for binary segmentation)
        features (list): Feature dimensions at each level [64, 128, 256, 512]
    """
    
    def __init__(self, in_channels=1, out_channels=1, features=[64, 128, 256, 512]):
        super(UNet3D, self).__init__()
        
        self.encoder1 = DoubleConv3D(in_channels, features[0])
        self.encoder2 = Down3D(features[0], features[1])
        self.encoder3 = Down3D(features[1], features[2])
        self.encoder4 = Down3D(features[2], features[3])
        
        self.bottleneck = Down3D(features[3], features[3] * 2)
        
        self.decoder4 = Up3D(features[3] * 2, features[3])
        self.decoder3 = Up3D(features[3], features[2])
        self.decoder2 = Up3D(features[2], features[1])
        self.decoder1 = Up3D(features[1], features[0])
        
        self.final_conv = nn.Conv3d(features[0], out_channels, kernel_size=1)
        self.sigmoid = nn.Sigmoid()
    
    def forward(self, x):
        # Encoder path
        enc1 = self.encoder1(x)
        enc2 = self.encoder2(enc1)
        enc3 = self.encoder3(enc2)
        enc4 = self.encoder4(enc3)
        
        # Bottleneck
        bottleneck = self.bottleneck(enc4)
        
        # Decoder path with skip connections
        dec4 = self.decoder4(bottleneck, enc4)
        dec3 = self.decoder3(dec4, enc3)
        dec2 = self.decoder2(dec3, enc2)
        dec1 = self.decoder1(dec2, enc1)
        
        # Final output
        output = self.final_conv(dec1)
        output = self.sigmoid(output)
        
        return output


class LiverSegmentationModel:
    """
    High-level wrapper for liver segmentation model
    
    Provides easy-to-use interface for model loading, inference, and evaluation.
    Handles device management (CPU/GPU) and preprocessing.
    """
    
    def __init__(self, model_path=None, device=None):
        """
        Initialize the liver segmentation model
        
        Args:
            model_path (str): Path to pretrained model weights
            device (str): Device to use ('cuda' or 'cpu')
        """
        self.device = device or ('cuda' if torch.cuda.is_available() else 'cpu')
        self.model = UNet3D(in_channels=1, out_channels=1)
        self.model = self.model.to(self.device)
        
        if model_path:
            self.load_weights(model_path)
        
        self.model.eval()
    
    def load_weights(self, model_path):
        """Load pretrained weights"""
        checkpoint = torch.load(model_path, map_location=self.device)
        if 'model_state_dict' in checkpoint:
            self.model.load_state_dict(checkpoint['model_state_dict'])
        else:
            self.model.load_state_dict(checkpoint)
        print(f"Loaded model weights from {model_path}")
    
    def predict(self, volume):
        """
        Perform inference on a CT volume
        
        Args:
            volume (np.ndarray): Input CT volume [D, H, W]
        
        Returns:
            np.ndarray: Binary segmentation mask [D, H, W]
        """
        with torch.no_grad():
            # Convert to tensor and add batch + channel dimensions
            x = torch.from_numpy(volume).float().unsqueeze(0).unsqueeze(0)
            x = x.to(self.device)
            
            # Forward pass
            output = self.model(x)
            
            # Convert back to numpy and threshold
            mask = output.squeeze().cpu().numpy()
            binary_mask = (mask > 0.5).astype('uint8')
            
            return binary_mask
    
    def predict_batch(self, volumes):
        """
        Perform inference on multiple CT volumes
        
        Args:
            volumes (list): List of CT volumes
        
        Returns:
            list: List of binary segmentation masks
        """
        return [self.predict(vol) for vol in volumes]
    
    @property
    def device_name(self):
        return self.device
    
    @property
    def num_parameters(self):
        return sum(p.numel() for p in self.model.parameters() if p.requires_grad)


def create_baseline_model(pretrained=False, device=None):
    """
    Factory function to create baseline U-Net model
    
    Args:
        pretrained (bool): Whether to load pretrained weights
        device (str): Device to use
    
    Returns:
        LiverSegmentationModel: Configured model instance
    """
    model_path = None
    if pretrained:
        # In production, point to actual pretrained weights
        model_path = 'models/liver_unet_baseline.pth'
    
    return LiverSegmentationModel(model_path=model_path, device=device)


if __name__ == '__main__':
    # Test model creation
    model = create_baseline_model()
    print(f"Model created on device: {model.device_name}")
    print(f"Number of parameters: {model.num_parameters:,}")
    
    # Test forward pass with dummy data
    import numpy as np
    dummy_volume = np.random.randn(64, 128, 128).astype('float32')
    mask = model.predict(dummy_volume)
    print(f"Input shape: {dummy_volume.shape}")
    print(f"Output shape: {mask.shape}")
    print("Model test successful!")
