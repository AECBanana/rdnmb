import { Post, PostRaw } from '../models/Post';
import { PostImage } from './PostImage';
import { HPRichTextV2, RichTextOptionModelV2 } from '@ohasasugar/hp-richtext';

@Component
export struct ReplyItem {
  @Prop reply: Post = new Post({
    id: '0'
  });
  @Prop content: string = '';
  private richTextModel: RichTextOptionModelV2 = new RichTextOptionModelV2();

  aboutToAppear(): void {
    this.updateRichText();
  }

  updateRichText(): void {
    this.richTextModel.richTextOption = {
      content: this.content.length > 0 ? this.content : this.reply.content,
      baseFontSize: 14,
      baseFontColor: '#333333'
    };
  }

  build() {
    Column() {
      Row() {
        Text(this.reply.userId)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
          .fontFamily('monospace')

        if (this.reply.createdAtText.length > 0) {
          Text(this.reply.createdAtText)
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
            .margin({ left: 8 })
        }
        if (this.reply.marked_admin) {
          Text('版主')
            .fontSize(10)
            .fontColor($r('app.color.admin_badge_text'))
            .backgroundColor($r('app.color.admin_badge_bg'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .margin({ left: 8 })
        }
        Text(`No.${this.reply.id}`)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
          .fontFamily('monospace')
      }
      .width('100%')
      .margin({ top: 6 })

      if (this.reply.title) {
        Text(this.reply.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 6 })
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
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 8 })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: $r('app.color.card_shadow'),
      offsetX: 0,
      offsetY: 2
    })
  }
}
