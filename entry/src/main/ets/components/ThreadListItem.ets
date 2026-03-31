import { BoardThread, BoardThreadRaw } from "../models/Post";
import { PostImage } from "./PostImage";
import { HPRichTextV2, RichTextOptionModelV2 } from "@ohasasugar/hp-richtext";
@Component
export struct ThreadListItem {
  @Prop @Watch("updateRichText") thread: BoardThread = new BoardThread({
    id: "0",
  });
  @Prop @Watch("updateRichText") content: string = "";
  onItemClick?: (threadId: number) => void;
  private richTextModel: RichTextOptionModelV2 = new RichTextOptionModelV2();

  aboutToAppear(): void {
    this.updateRichText();
  }

  updateRichText(): void {
    let rawContent: string = this.content.length > 0 ? this.content : this.thread.content;
    let displayContent: string = rawContent.replace(/\\n/g, "").replace(/\n/g, "");
    if (displayContent.length > 500) {
      displayContent = displayContent.substring(0, 500) + "...";
    }
    this.richTextModel.richTextOption = {
      content: displayContent,
      baseFontSize: 14,
      baseFontColor: "#333333",
    };
  }

  formatRelativeTime(timeStr: string): string {
    if (timeStr.length === 0) {
      return "";
    }

    const match: RegExpMatchArray | null = timeStr.match(
      /(\d{4})-(\d{1,2})-(\d{1,2})\([^)]+\)(\d{2}):(\d{2}):(\d{2})/,
    );
    if (match === null || match.length < 7) {
      return timeStr;
    }

    const year: number = parseInt(match[1]);
    const month: number = parseInt(match[2]) - 1;
    const day: number = parseInt(match[3]);
    const hour: number = parseInt(match[4]);
    const minute: number = parseInt(match[5]);
    const second: number = parseInt(match[6]);

    const postDate: Date = new Date(year, month, day, hour, minute, second);
    const now: Date = new Date();
    const diffMs: number = now.getTime() - postDate.getTime();

    if (diffMs < 0) {
      return "刚刚";
    }

    const diffSeconds: number = Math.floor(diffMs / 1000);
    const diffMinutes: number = Math.floor(diffSeconds / 60);
    const diffHours: number = Math.floor(diffMinutes / 60);
    const diffDays: number = Math.floor(diffHours / 24);
    const diffMonths: number = Math.floor(diffDays / 30);
    const diffYears: number = Math.floor(diffDays / 365);

    if (diffSeconds < 60) {
      return "刚刚";
    } else if (diffMinutes < 60) {
      return `${diffMinutes}分钟前`;
    } else if (diffHours < 24) {
      return `${diffHours}小时前`;
    } else if (diffDays < 30) {
      return `${diffDays}天前`;
    } else if (diffMonths < 12) {
      return `${diffMonths}个月前`;
    } else {
      return `${diffYears}年前`;
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          if (this.thread.title) {
            Text(this.thread.title)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r("app.color.text_primary"))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width("100%")
              .lineHeight(22);
          }
          Row() {
            Text(this.thread.userId)
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
              .fontWeight(FontWeight.Bold)

            Text(`No.${this.thread.id}`)
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
              .margin({ left: 8})

            if (this.thread.createdAtText.length > 0) {
              Text(this.formatRelativeTime(this.thread.createdAtText))
                .fontSize(11)
                .fontColor($r("app.color.text_secondary"))
                .margin({ left: 8 });
            }

            if (this.thread.marked_admin) {
              Text("红名")
                .fontSize(10)
                .fontColor($r("app.color.admin_badge_text"))
                .backgroundColor($r("app.color.admin_badge_bg"))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
                .margin({ left: 8 });
            }
          }
          .margin({ top: 6 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Row() {
          Text(`${this.thread.totalReplyCount}`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r("app.color.primary"))
            .backgroundColor($r("app.color.reply_count_bg"))
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(12)
        }
        .margin({ left: 8 })
      }
      .width("100%")
      .alignItems(VerticalAlign.Top)
      Row() {
        if (this.thread.thumbnailUrl) {
          PostImage({ post: this.thread, imageWidth: 80, imageHeight: 80 });
        }
        Column() {
          HPRichTextV2({
            richTextModel: this.richTextModel,
          })
        }
        .hitTestBehavior(HitTestMode.Transparent)
        .layoutWeight(1)
        .margin({ left: this.thread.thumbnailUrl ? 12 : 0 })
        .alignItems(HorizontalAlign.Start)
      }
      .width("100%")
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Top)
    }
    .width("100%")
    .padding(14)
    .backgroundColor($r("app.color.card_background"))
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: $r("app.color.card_shadow"),
      offsetX: 0,
      offsetY: 2,
    })
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick(this.thread.id);
      }
    });
  }
}
