import router from '@ohos.router';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { ImageCacheManager } from '../utils/ImageCacheManager';

interface ImagePreviewParams {
  imageUrl: string;
}

@Entry
@Component
struct ImagePreviewPage {
  @State imageUrl: string = '';
  @State isLoading: boolean = true;
  @State errorMessage: string = '';
  @State scaleValue: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State imagePixelMap: image.PixelMap | null = null;
  @State isSaving: boolean = false;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private imageCacheManager: ImageCacheManager = ImageCacheManager.getInstance();

  aboutToAppear() {
    const params = router.getParams() as ImagePreviewParams;
    if (params && params.imageUrl) {
      this.imageUrl = params.imageUrl;
      this.downloadImage();
    }
  }

  async downloadImage() {
    if (!this.imageUrl) {
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    const pixelMap: image.PixelMap | null = await this.imageCacheManager.downloadAndCache(this.imageUrl);
    if (pixelMap) {
      this.imagePixelMap = pixelMap;
      this.isLoading = false;
    } else {
      this.isLoading = false;
      this.errorMessage = '图片加载失败';
    }
  }

  async saveImageToGallery(): Promise<void> {
    if (!this.imagePixelMap) {
      promptAction.showToast({ message: '图片未加载完成' });
      return;
    }

    this.isSaving = true;
    try {
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const uri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      const file: fileIo.File = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);

      const imagePacker: image.ImagePacker = image.createImagePacker();
      const packingOptions: image.PackingOption = {
        format: 'image/jpeg',
        quality: 95
      };
      const packData: ArrayBuffer = await imagePacker.packing(this.imagePixelMap, packingOptions);
      imagePacker.release();

      await fileIo.write(file.fd, packData);
      await fileIo.close(file.fd);

      promptAction.showToast({ message: '已保存到相册' });
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`Failed to save photo. Code is ${err.code}, message is ${err.message}`);
      promptAction.showToast({ message: `保存失败: ${err.message}` });
    } finally {
      this.isSaving = false;
    }
  }

  build() {
    Column() {
      Row() {
        Button() {
          Text('关闭')
            .fontSize(16)
            .fontColor(Color.White)
        }
        .backgroundColor('transparent')
        .onClick(() => {
          router.back();
        })

        Blank()

        if (this.isLoading) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(Color.White)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('rgba(0,0,0,0.8)')

      if (this.errorMessage) {
        Column() {
          Text('图片加载失败')
            .fontSize(16)
            .fontColor(Color.White)
          Text(this.errorMessage)
            .fontSize(12)
            .fontColor('#aaaaaa')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.isLoading) {
            Column() {
              LoadingProgress()
                .width(48)
                .height(48)
                .color(Color.White)
              Text('加载中...')
                .fontSize(14)
                .fontColor(Color.White)
                .margin({ top: 16 })
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }

          if (this.imagePixelMap) {
            Image(this.imagePixelMap)
              .objectFit(ImageFit.Contain)
              .width('100%')
              .height('100%')
              .scale({ x: this.scaleValue, y: this.scaleValue })
              .translate({ x: this.offsetX, y: this.offsetY })
              .gesture(
                PinchGesture()
                  .onActionUpdate((event) => {
                    this.scaleValue = Math.max(0.5, Math.min(4, this.scaleValue * event.scale));
                  })
                  .onActionEnd(() => {
                    if (this.scaleValue < 1) {
                      this.scaleValue = 1;
                      this.offsetX = 0;
                      this.offsetY = 0;
                    }
                  })
              )
              .gesture(
                PanGesture()
                  .onActionUpdate((event) => {
                    this.offsetX += event.offsetX;
                    this.offsetY += event.offsetY;
                  })
                  .onActionEnd(() => {
                    if (this.scaleValue <= 1) {
                      this.offsetX = 0;
                      this.offsetY = 0;
                    }
                  })
              )
          }

          Stack() {
            SaveButton()
              .width(50)
              .height(50)
              .onClick(async (event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  await this.saveImageToGallery();
                } else {
                  promptAction.showToast({ message: '授权失败' });
                }
              })
          }
          .padding({ right: 20, bottom: 30 })
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(Color.Black)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
