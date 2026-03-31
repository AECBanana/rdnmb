import router from '@ohos.router';
import { Post } from '../models/Post';
import { image } from '@kit.ImageKit';
import { ImageCacheManager } from '../utils/ImageCacheManager';

@Component
export struct PostImage {
  @Prop post: Post = new Post({ id: '0' });
  @Prop imageWidth: number = 120;
  @Prop imageHeight: number = 120;
  @State private imageLoaded: boolean = false;
  @State private imageError: boolean = false;
  @State private pixelMap: image.PixelMap | null = null;

  private imageCacheManager: ImageCacheManager = ImageCacheManager.getInstance();

  aboutToAppear(): void {
    this.loadImage();
  }

  async loadImage(): Promise<void> {
    const thumbnailUrl = this.post.thumbnailUrl;
    if (!thumbnailUrl) {
      return;
    }

    this.imageLoaded = false;
    this.imageError = false;

    const pixelMap = await this.imageCacheManager.downloadAndCache(thumbnailUrl);
    if (pixelMap) {
      this.pixelMap = pixelMap;
      this.imageLoaded = true;
    } else {
      this.imageError = true;
    }
  }

  openImagePreview(): void {
    const fullUrl = this.post.attachmentUrl;
    if (fullUrl) {
      router.pushUrl({
        url: 'pages/ImagePreviewPage',
        params: {
          imageUrl: fullUrl
        }
      });
    }
  }

  build() {
    Stack() {
      if (this.pixelMap) {
        Image(this.pixelMap)
          .width(this.imageWidth)
          .height(this.imageHeight)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .backgroundColor($r('app.color.image_placeholder'))
      } else if (this.post.thumbnailUrl) {
        Image(this.post.thumbnailUrl)
          .width(this.imageWidth)
          .height(this.imageHeight)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .backgroundColor($r('app.color.image_placeholder'))
          .onComplete(() => {
            this.imageLoaded = true;
          })
          .onError(() => {
            this.imageError = true;
          })
      }

      if (!this.imageLoaded && !this.imageError && !this.pixelMap) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color($r('app.color.primary'))
        }
        .width(this.imageWidth)
        .height(this.imageHeight)
        .justifyContent(FlexAlign.Center)
        .borderRadius(8)
        .backgroundColor($r('app.color.image_placeholder'))
      }

      if (this.imageError) {
        Column() {
          Text('加载失败')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(this.imageWidth)
        .height(this.imageHeight)
        .justifyContent(FlexAlign.Center)
        .borderRadius(8)
        .backgroundColor($r('app.color.image_placeholder'))
      }
    }
    .width(this.imageWidth)
    .height(this.imageHeight)
    .onClick(() => {
      this.openImagePreview();
    })
  }
}
