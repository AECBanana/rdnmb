import { Post, PostRaw } from '../models/Post';
import { PostImage } from './PostImage';
import { HPRichTextV2, RichTextOptionModelV2 } from '@ohasasugar/hp-richtext';

@Component
export struct ReplyItem {
  @Prop reply: Post = new Post({
    id: '0'
  });
  private richTextModel: RichTextOptionModelV2 = new RichTextOptionModelV2();

  aboutToAppear(): void {
    this.richTextModel.richTextOption = {
      content: this.reply.content,
      baseFontSize: 14,
      baseFontColor: '#333333'
    };
  }

  build() {
    Column() {
      Row() {
        Text(this.reply.userId)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))

        if (this.reply.createdAtText.length > 0) {
          Text(this.reply.createdAtText)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8 })
        }

        if (this.reply.marked_admin) {
          Text('版主')
            .fontSize(12)
            .fontColor('#ff6b6b')
            .backgroundColor('#fff0f0')
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius(4)
            .margin({ left: 8 })
        }

        Text(`No.${this.reply.id}`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      if (this.reply.title) {
        Text(this.reply.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 8 })
          .width('100%')
      }

      Row() {
        if (this.reply.thumbnailUrl) {
          PostImage({ post: this.reply, imageWidth: 100, imageHeight: 100 })
        }

        Column() {
          HPRichTextV2({
            richTextModel: this.richTextModel
          })
        }
        .layoutWeight(1)
        .margin({ left: this.reply.thumbnailUrl ? 12 : 0 })
      }
      .width('100%')
      .margin({ top: 8 })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(8)
  }
}
