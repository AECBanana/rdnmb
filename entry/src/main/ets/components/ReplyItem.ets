import { Post } from "../models/Post";
import { PostImage } from "./PostImage";
import { HPRichTextV2, RichTextOptionModelV2 } from "@ohasasugar/hp-richtext";
import common from "@ohos.app.ability.common";

interface LinkPressEvent {
  href?: string;
  link?: string;
  text?: string;
}
@Component
export struct ReplyItem {
  @Prop reply: Post = new Post({
    id: "0",
  });
  @Prop content: string = "";
  @Prop threadUserid?: string = "";
  @Prop isHighlighted: boolean = false;
  onReplyClick?: (replyId: string) => void;
  onJumpToReply?: (replyId: string) => void;
  private richTextModel: RichTextOptionModelV2 = new RichTextOptionModelV2();
  private tipsId: number = 9999999;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.updateRichText();
  }

  processContent(rawContent: string): string {
    let content: string = rawContent.replace(/\\n/g, "").replace(/\n/g, "");
    content = this.convertReplyLinks(content);
    content = this.convertUrlsToLinks(content);
    return content;
  }

  convertReplyLinks(content: string): string {
    const replyPattern: RegExp = /&gt;&gt;No\.(\d+)/g;
    return content.replace(replyPattern, '<a href="reply:$1">&gt;&gt;No.$1</a>');
  }

  convertUrlsToLinks(content: string): string {
    const urlPattern: RegExp = /(https?:\/\/[^\s<>"']+)/g;
    return content.replace(urlPattern, '<a href="$1">$1</a>');
  }

  updateRichText(): void {
    let rawContent: string = this.content.length > 0 ? this.content : this.reply.content;
    let displayContent: string = this.processContent(rawContent);
    this.richTextModel.richTextOption = {
      content: displayContent,
      baseFontSize: $r("app.float.content_text_font"),
      baseFontColor: "#333333",
    };
    this.richTextModel.onLinkPress = (e: LinkPressEvent): LinkPressEvent => {
      console.info(`[ReplyItem] Link pressed: ${JSON.stringify(e)}`);

      let linkValue: string | undefined = undefined;
      if (e !== null && e !== undefined) {
        if (e.link !== undefined) {
          linkValue = e.link;
        } else if (e.href !== undefined) {
          linkValue = e.href;
        }
      }

      if (linkValue !== undefined) {
        if (linkValue.startsWith("reply:")) {
          const replyId: string = linkValue.substring(6);
          console.info(`[ReplyItem] Jump to reply: ${replyId}`);
          if (this.onJumpToReply) {
            this.onJumpToReply(replyId);
          }
          return e;
        }
        this.openLink(linkValue);
      } else if (e !== null && e !== undefined && e.text !== undefined) {
        const text: string = e.text;
        const urlMatch: RegExpMatchArray | null = text.match(/https?:\/\/[^\s`]+/);
        if (urlMatch !== null && urlMatch.length > 0) {
          this.openLink(urlMatch[0]);
        }
      }
      return e;
    };
  }

  async openLink(url: string) {
    try {
      await this.context.openLink(url);
      console.info(`[ReplyItem] Opened link: ${url}`);
    } catch (error) {
      console.error(`[ReplyItem] Failed to open link: ${error}`);
    }
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

  @Builder
  replyMenuBuilder() {
    Menu() {
      MenuItem({
        content: "回复",
      })
        .onClick(() => {
          if (this.onReplyClick) {
            this.onReplyClick(String(this.reply.id));
          }
        })
    };
  }

  build() {
    Column() {
      if (this.reply.id == this.tipsId) {
        RelativeContainer() {
          if (this.reply.attachmentUrl) {
            PostImage({ post: this.reply, imageWidth: 80, imageHeight: 80 })
              .alignRules({
                left: { anchor: "__container__", align: HorizontalAlign.Start },
              })
              .id("image")
              .margin({ top: 10 });
          }
          Text(this.reply.content)
            .fontSize(14)
            .alignRules({
              left: {
                anchor: this.reply.attachmentUrl ? "image" : "__container__",
                align: this.reply.attachmentUrl ? HorizontalAlign.End : HorizontalAlign.Start,
              },
            })
            .fontColor($r("app.color.text_secondary"))
            .padding({ left: 10 })
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width("100%")
        .height("auto");
      } else {
        RelativeContainer() {
          if (this.reply.title) {
            Text(this.reply.title)
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
            if (this.reply.userId == this.threadUserid) {
              Text("PO")
                .fontSize(10)
                .fontColor($r("app.color.po_badge_text"))
                .backgroundColor($r("app.color.po_badge_bg"))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4);
            }
            Text(this.reply.userId)
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
              .fontWeight(FontWeight.Bold)
              .margin({ left: this.reply.userId == this.threadUserid ? 8 : 0 })
            Text(`No.${this.reply.id}`)
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
              .margin({ left: 8 })

            if (this.reply.createdAtText.length > 0) {
              Text(this.formatRelativeTime(this.reply.createdAtText))
                .fontSize(11)
                .fontColor($r("app.color.text_secondary"))
                .margin({ left: 8 });
            }

            if (this.reply.marked_admin) {
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
              anchor: this.reply.title ? "title" : "",
              align: this.reply.title ? VerticalAlign.Bottom : VerticalAlign.Top,
            },
            left: { anchor: "__container__", align: HorizontalAlign.Start },
          })

          if (this.reply.thumbnailUrl) {
            PostImage({ post: this.reply, imageWidth: 80, imageHeight: 80 })
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
              anchor: this.reply.thumbnailUrl ? "image" : "",
              align: this.reply.attachmentUrl ? HorizontalAlign.End : HorizontalAlign.Start,
            },
            right: { anchor: "__container__", align: HorizontalAlign.End },
          })
          .height("auto")
          .padding({
            top: 10,
            left: this.reply.thumbnailUrl ? 10 : 0,
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
        }
        .width("100%")
        .height("auto")
        .padding(14)
        .backgroundColor(
          this.isHighlighted ? $r("app.color.card_light") : $r("app.color.card_background"),
        )
        .borderRadius(12)
        .shadow({
          radius: 4,
          color: $r("app.color.card_shadow"),
          offsetX: 0,
          offsetY: 2,
        })
        .bindContextMenu(this.replyMenuBuilder, ResponseType.LongPress | ResponseType.RightClick);
      }
    };
  }
}

// Preview组件用于测试ReplyItem
@Preview
@Component
struct ReplyItemPreview {
  build() {
    Column() {
      // 测试用例1: 普通回复（无图片）
      ReplyItem({
        reply: new Post({
          id: "12345",
          user_id: "Anonymous",
          now: "2024-01-15(周一)10:30:00",
          content: "这是一个普通的回复内容，用于测试ReplyItem组件的显示效果。",
        }),
      })
        .margin({ bottom: 16 })

      // 测试用例2: 有图片的回复
      ReplyItem({
        reply: new Post({
          id: "67890",
          user_id: "User123",
          now: "2024-01-15(周一)11:00:00",
          content: "这个回复包含图片附件，测试图片显示功能。",
          img: "test",
          ext: ".jpg",
        }),
      })
        .margin({ bottom: 16 })

      // 测试用例3: 管理员回复
      ReplyItem({
        reply: new Post({
          id: "11111",
          user_id: "Admin",
          now: "2024-01-15(周一)09:00:00",
          content: "这是管理员的回复，测试红名标识显示。",
          admin: "1",
        }),
      })
        .margin({ bottom: 16 })

      // 测试用例4: SAGE回复
      ReplyItem({
        reply: new Post({
          id: "22222",
          user_id: "SageUser",
          now: "2024-01-15(周一)12:00:00",
          content: "这是SAGE回复，测试SAGE标识显示。",
          sage: "1",
        }),
      })
        .margin({ bottom: 16 })

      // 测试用例5: PO（发帖者）回复
      ReplyItem({
        reply: new Post({
          id: "33333",
          user_id: "ThreadOwner",
          now: "2024-01-15(周一)13:00:00",
          content: "这是发帖者的回复，测试PO标识显示。",
        }),
        threadUserid: "ThreadOwner",
      })
        .margin({ bottom: 16 })

      // 测试用例6: 带标题的回复
      ReplyItem({
        reply: new Post({
          id: "44444",
          user_id: "TitleUser",
          now: "2024-01-15(周一)14:00:00",
          title: "回复标题",
          content: "这是一个带标题的回复，测试标题显示功能。",
        }),
      })
        .margin({ bottom: 16 })

      // 测试用例7: 长内容回复
      ReplyItem({
        reply: new Post({
          id: "55555",
          user_id: "LongContentUser",
          now: "2024-01-15(周一)15:00:00",
          content:
            "这是一个非常长的回复内容，用于测试文本显示和布局。这里添加更多内容来测试组件对长文本的处理能力：Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        }),
      })
        .margin({ bottom: 16 })

      // 测试用例8: 组合多种标识的回复
      ReplyItem({
        reply: new Post({
          id: "66666",
          user_id: "ComboUser",
          now: "2024-01-15(周一)16:00:00",
          title: "组合测试",
          content: "这个回复包含图片、管理员标识和SAGE标识的组合测试。",
          img: "test",
          ext: ".jpg",
          admin: "1",
          sage: "1",
        }),
      })
    }
    .width("100%")
    .padding(16)
    .backgroundColor($r("app.color.background"));
  }
}
