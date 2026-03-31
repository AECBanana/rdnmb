import { BoardThread, BoardThreadRaw } from '../models/Post';
import { PostImage } from './PostImage';
import { HPRichTextV2, RichTextOptionModelV2 } from '@ohasasugar/hp-richtext';

@Component
export struct ThreadListItem {
  @Prop @Watch('updateRichText') thread: BoardThread = new BoardThread({
    id: '0'
  });
  @Prop @Watch('updateRichText') content: string = '';
  onItemClick?: (threadId: number) => void;
  private richTextModel: RichTextOptionModelV2 = new RichTextOptionModelV2();

  aboutToAppear(): void {
    this.updateRichText();
  }

  updateRichText(): void {
    this.richTextModel.richTextOption = {
      content: this.content.length > 0 ? this.content : this.thread.content,
      baseFontSize: 14,
      baseFontColor: '#333333'
    };
  }

  build() {
    Column() {
      Row() {
        Column() {
          if (this.thread.title) {
            Text(this.thread.title)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }

          Row() {
            Text(`No.${this.thread.id}`)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))

            if (this.thread.createdAtText.length > 0) {
              Text(this.thread.createdAtText)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 8 })
            }

            if (this.thread.marked_admin) {
              Text('版主')
                .fontSize(12)
                .fontColor('#ff6b6b')
                .backgroundColor('#fff0f0')
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .borderRadius(4)
                .margin({ left: 8 })
            }
          }
          .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(`${this.thread.totalReplyCount}`)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.reply_count_bg'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(12)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row() {
        if (this.thread.thumbnailUrl) {
          PostImage({ post: this.thread, imageWidth: 80, imageHeight: 80 })
        }

        Column() {
          HPRichTextV2({
            richTextModel: this.richTextModel
          })
        }
        .layoutWeight(1)
        .margin({ left: this.thread.thumbnailUrl ? 12 : 0 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 8 })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(8)
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick(this.thread.id);
      }
    })
  }
}
