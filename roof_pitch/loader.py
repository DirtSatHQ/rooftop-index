import os
from pathlib import Path
from PIL import Image
from torchvision.transforms import ToTensor
from torch.utils.data import Dataset


class RoofLoader(Dataset):

    def __init__(self, data_dir='./data/rooftops'):

        self.f_list = [x for x in Path(data_dir).rglob('*.tif')]

    def __len__(self):
        return len(self.f_list)

    def __getitem__(self, idx):

        pth = self.f_list[idx]
        roof_type = os.path.basename(os.path.dirname(pth))

        image = Image.open(pth)
        x = ToTensor()(image)

        y = 1 if roof_type == 'Flat' else 0

        return x, y