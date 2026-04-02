import router from "@ohos.router";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { fileIo } from "@kit.CoreFileKit";
import { common } from "@kit.AbilityKit";
import { promptAction } from "@kit.ArkUI";
import { BusinessError } from "@kit.BasicServicesKit";
import { image } from "@kit.ImageKit";
import { ImageCacheManager } from "../utils/ImageCacheManager";
import { PhotoView } from "@ohos/photoview";

interface ImagePreviewParams {
  imageUrl: string;
}

@Entry
@ComponentV2
struct ImagePreviewPage {
  @Local imageUrl: string = "";
  @Local isLoading: boolean = true;
  @Local errorMessage: string = "";
  @Local imagePixelMap: image.PixelMap | null = null;
  @Local isSaving: boolean = false;
  @Local photoModel: PhotoView.Model = new PhotoView.Model();

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private imageCacheManager: ImageCacheManager = ImageCacheManager.getInstance();

  aboutToAppear() {
    const params = router.getParams() as ImagePreviewParams;
    if (params && params.imageUrl) {
      this.imageUrl = params.imageUrl;
      this.downloadImage();
    }
    this.photoModel
      .setScale(1, true)
      .setImageFit(ImageFit.Contain)
      .setZoomable(true)
      .setMaximumScale(4)
      .setMinimumScale(0.5);
  }

  async downloadImage() {
    if (!this.imageUrl) {
      return;
    }

    this.isLoading = true;
    this.errorMessage = "";

    const pixelMap: image.PixelMap | null = await this.imageCacheManager.downloadAndCache(
      this.imageUrl,
    );
    if (pixelMap) {
      this.imagePixelMap = pixelMap;
      this.photoModel.setImageElement(pixelMap);
      this.isLoading = false;
    } else {
      this.isLoading = false;
      this.errorMessage = "图片加载失败";
    }
  }

  async saveImageToGallery(): Promise<void> {
    if (!this.imagePixelMap) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: "图片未加载完成" })
      } catch (error) {
        // TODO: Implement error handling.
      }
      return;
    }

    this.isSaving = true;
    try {
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(
        this.context,
      );
      const uri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, "jpg");
      const file: fileIo.File = await fileIo.open(
        uri,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE,
      );

      const imagePacker: image.ImagePacker = image.createImagePacker();
      const packingOptions: image.PackingOption = {
        format: "image/jpeg",
        quality: 95,
      };
      const packData: ArrayBuffer = await imagePacker.packing(this.imagePixelMap, packingOptions);
      imagePacker.release();

      await fileIo.write(file.fd, packData);
      await fileIo.close(file.fd);

      promptAction.showToast({ message: "已保存到相册" });
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
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r("sys.symbol.xmark"))
            .fontSize(18)
        }
        .backgroundColor(Color.Grey)
        .width(48)
        .height(48)
        .onClick(() => {
          router.back();
        })
        Blank()
      }
      .width("100%")
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor("rgba(0,0,0,0.8)")

      if (this.errorMessage) {
        Column() {
          Text("图片加载失败")
            .fontSize(16)
            .fontColor(Color.White)
          Text(this.errorMessage)
            .fontSize(12)
            .fontColor("#aaaaaa")
            .margin({ top: 8 })
        }
        .width("100%")
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.isLoading) {
            Column() {
              LoadingProgress()
                .width(48)
                .height(48)
                .color(Color.White)
              Text("加载中...")
                .fontSize(14)
                .fontColor(Color.White)
                .margin({ top: 16 })
            }
            .width("100%")
            .height("100%")
            .justifyContent(FlexAlign.Center);
          }

          if (this.imagePixelMap) {
            PhotoView({ model: this.photoModel }).width("100%").height("100%");
          }
          Stack() {
            SaveButton({ buttonType: ButtonType.Circle,icon: SaveIconStyle.FULL_FILLED })
              .setText("")
              .width(48)
              .backgroundColor(Color.Grey)
              .onClick(async (event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  await this.saveImageToGallery();
                } else {
                  promptAction.showToast({ message: "授权失败导致保存失败" });
                }
              })
          }
          .padding({ right: 20, bottom: 30 })
        }
        .width("100%")
        .layoutWeight(1)
        .backgroundColor(Color.Black);
      }
    }
    .width("100%")
    .height("100%")
    .padding({ left: 8, right: 8, top: 44, bottom: 8 })
    .backgroundColor(Color.Black);
  }
}
