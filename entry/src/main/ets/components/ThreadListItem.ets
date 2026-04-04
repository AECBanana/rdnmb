import { BoardThread } from "../models/Post";
import { PostImage } from "./PostImage";
import { HPRichTextV2, RichTextOptionModelV2 } from "@ohasasugar/hp-richtext";
@Component
export struct ThreadListItem {
  @Prop @Watch("updateRichText") thread: BoardThread = new BoardThread({
    id: "0",
  });
  @Prop @Watch("updateRichText") content: string = "";
  @Prop boardNameMap: Map<number, string> = new Map();
  @Prop isTimeline: boolean = false;
  onItemClick?: (threadId: number) => void;
  private richTextModel: RichTextOptionModelV2 = new RichTextOptionModelV2();

  aboutToAppear(): void {
    this.updateRichText();
  }

  updateRichText(): void {
    let rawContent: string = this.content.length > 0 ? this.content : this.thread.content;
    let displayContent: string = rawContent.replace(/\\n/g, "").replace(/\n/g, "");
    if (displayContent.length > 200) {
      displayContent = displayContent.substring(0, 200) + "...";
    }
    this.richTextModel.richTextOption = {
      content: displayContent,
      baseFontSize: $r("app.float.content_text_font"),
      baseFontColor: $r("app.color.text_primary"),
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
      RelativeContainer() {
        if (this.thread.title) {
          Text(this.thread.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r("app.color.text_primary"))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(22)
            .id("title")
            .alignRules({
              left: { anchor: "__container__", align: HorizontalAlign.Start },
              right: { anchor: "replyCount", align: HorizontalAlign.Start },
            })
            .margin({ right: 8 });
        }
        Row() {
          Text(this.thread.userId)
            .fontSize(11)
            .fontColor($r("app.color.text_secondary"))
            .fontWeight(FontWeight.Bold)
          Text(`No.${this.thread.id}`)
            .fontSize(11)
            .fontColor($r("app.color.text_secondary"))
            .margin({ left: 8 })

          if (this.thread.createdAtText.length > 0) {
            Text(this.formatRelativeTime(this.thread.createdAtText))
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
              .margin({ left: 8 });
          }

          if (this.isTimeline && this.thread.boardId !== null) {
            Text(this.boardNameMap.get(this.thread.boardId) ?? "")
              .fontSize(11)
              .fontColor($r("app.color.primary"))
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
        .id("userInfo")
        .alignRules({
          top: {
            anchor: this.thread.title ? "title" : "",
            align: this.thread.title ? VerticalAlign.Bottom : VerticalAlign.Top,
          },
          left: { anchor: "__container__", align: HorizontalAlign.Start },
        })
        .margin({ top: 6 })
        Text(`${this.thread.totalReplyCount}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r("app.color.primary"))
          .backgroundColor($r("app.color.reply_count_bg"))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .id("replyCount")
          .alignRules({
            right: { anchor: "__container__", align: HorizontalAlign.End },
          })

        if (this.thread.thumbnailUrl) {
          PostImage({ post: this.thread, imageWidth: 80, imageHeight: 80 })
            .id("image")
            .alignRules({
              top: { anchor: "userInfo", align: VerticalAlign.Bottom },
              left: { anchor: "__container__", align: HorizontalAlign.Start },
            })
            .margin({ top: 10 });
        }
        Column() {
          HPRichTextV2({
            richTextModel: this.richTextModel,
          })
        }
        .id("content")
        .alignRules({
          top: { anchor: "userInfo", align: VerticalAlign.Bottom },
          left: {
            anchor: this.thread.thumbnailUrl ? "image" : "",
            align: this.thread.attachmentUrl ? HorizontalAlign.End : HorizontalAlign.Start,
          },
          right: { anchor: "__container__", align: HorizontalAlign.End },
        })
        .height("auto")
        .padding({
          top: 10,
          left: this.thread.thumbnailUrl ? 10 : 0,
        })
        Column()
          .hitTestBehavior(HitTestMode.Transparent)
          .id("clickArea")
          .backgroundColor(Color.Transparent)
          .alignRules({
            top: { anchor: "content", align: VerticalAlign.Top },
            left: { anchor: "content", align: HorizontalAlign.Start },
            right: { anchor: "content", align: HorizontalAlign.End },
            bottom: { anchor: "content", align: VerticalAlign.Bottom },
          })
          .zIndex(1)
          .margin({
            top: 10,
          })
          .onClick(() => {
            if (this.onItemClick) {
              this.onItemClick(this.thread.id);
            }
          })
      }
      .width("100%")
      .height("auto")
    }
    .width("100%")
    .height("auto")
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
      this.onItemClick?.(this.thread.id);
    });
  }
}

@Preview
@Component
struct ThreadListItemPreview {
  build() {
    Column() {
      ThreadListItem({
        thread: new BoardThread({
          id: "12345",
          user_id: "Anonymous",
          now: "2024-01-15(周一)10:30:00",
          title: "这是一个测试帖子的标题",
          content:
            "这是帖子的内容，用于测试ThreadListItem组件的显示效果。内容比较长，测试一下文本截断功能是否正常工作。",
          ReplyCount: "15",
        }),
      })
        .margin({ bottom: 16 })
      ThreadListItem({
        thread: new BoardThread({
          id: "67890",
          user_id: "Admin",
          now: "2024-01-15(周一)11:00:00",
          title: "带图片的测试帖子",
          content: "这个帖子有图片附件，测试图片显示功能。",
          img: "test",
          ext: ".jpg",
          ReplyCount: "8",
          admin: "1",
        }),
      })
        .margin({ bottom: 16 })
      ThreadListItem({
        thread: new BoardThread({
          id: "11111",
          user_id: "User123",
          now: "2024-01-15(周一)09:00:00",
          content: "这是一个没有标题的帖子，测试无标题情况下的显示效果。",
          ReplyCount: "3",
        }),
      })
        .margin({ bottom: 16 })
      ThreadListItem({
        thread: new BoardThread({
          id: "22222",
          user_id: "LongContent",
          now: "2024-01-15(周一)12:00:00",
          title: "长内容测试",
          content:
            "这是一个非常长的帖子内容，用于测试文本截断功能。这个内容应该超过500个字符，看看组件是否会正确截断并显示省略号。这里添加更多内容来确保长度足够：Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
          ReplyCount: "25",
        }),
      })
    }
    .width("100%")
    .padding(16)
    .backgroundColor($r("app.color.background"));
  }
}
