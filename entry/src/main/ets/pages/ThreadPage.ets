import router from "@ohos.router";
import { AnoBBSClient } from "../api/Client";
import { ThreadPage, ThreadPageRaw, Post, PostRaw } from "../models/Post";
import { ReplyItem } from "../components/ReplyItem";
import { PostImage } from "../components/PostImage";
import { RequiresLoginException } from "../models/Errors";
import { HPRichTextV2, RichTextOptionModelV2 } from "@ohasasugar/hp-richtext";

interface ThreadPageParams {
  threadId?: number;
}

@Entry
@Component
struct ThreadDetailPage {
  @State thread: ThreadPage | null = null;
  @State isLoading: boolean = true;
  @State isLoadingMore: boolean = false;
  @State errorMessage: string = "";
  @State currentPage: number = 1;
  @State totalPages: number = 1;
  @State threadId: number = 0;
  @State replyCount: number = 0;

  private client: AnoBBSClient = new AnoBBSClient();
  private scroller: Scroller = new Scroller();
  private static readonly REPLIES_PER_PAGE: number = 20;
  private threadRichTextModel: RichTextOptionModelV2 = new RichTextOptionModelV2();

  aboutToAppear() {
    const params = router.getParams() as ThreadPageParams;
    if (params && params.threadId) {
      this.threadId = params.threadId;
    }
  }

  onPageShow() {
    if (this.threadId > 0 && this.thread === null) {
      this.loadThread(this.threadId, 1);
    }
  }

  updateThreadRichTextModel(): void {
    if (this.thread) {
      this.threadRichTextModel.richTextOption = {
        content: this.thread.content,
        baseFontSize: 15,
        baseFontColor: "#333333",
      };
    }
  }

  async loadThread(threadId: number, page: number) {
    if (page === 1) {
      this.isLoading = true;
    } else {
      this.isLoadingMore = true;
    }
    this.errorMessage = "";

    try {
      const thread = await this.client.getThreadPage(threadId, page);
      if (page === 1) {
        this.thread = thread;
        this.calculateTotalPages(thread.totalReplyCount);
        this.updateThreadRichTextModel();
      } else if (this.thread !== null) {
        const newReplies = thread.raw.Replies;
        if (newReplies !== undefined && newReplies !== null) {
          this.thread.addReplies(newReplies);
          this.replyCount = this.thread.replyCount;
        }
      }
      this.currentPage = page;
    } catch (error) {
      if (error instanceof RequiresLoginException) {
        this.errorMessage = "需要饼干才能访问，请在设置中添加饼干";
      } else {
        const errorMsg = error instanceof Error ? error.message : String(error);
        this.errorMessage = `加载失败: ${errorMsg}`;
      }
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  calculateTotalPages(totalReplies: number): void {
    if (totalReplies <= 0) {
      this.totalPages = 1;
    } else {
      this.totalPages = Math.ceil(totalReplies / ThreadDetailPage.REPLIES_PER_PAGE);
    }
  }

  hasMoreReplies(): boolean {
    return this.currentPage < this.totalPages;
  }

  @Builder
  threadHeader() {
    if (this.thread) {
      Column() {
        Row() {
          Text(this.thread.userId)
            .fontColor($r("app.color.text_secondary"))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
          Text(`No.${this.thread.id}`)
            .fontSize(12)
            .fontColor($r("app.color.text_secondary"))
          Text(this.thread.createdAtText)
            .fontSize(12)
            .fontColor($r("app.color.text_secondary"))
            .margin({ left: 8 })
          Text("PO")
            .fontSize(12)
            .fontColor("#ff6b6b")
            .backgroundColor("#fff0f0")
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius(4)
            .margin({ left: 8 })
        }.width("100%")

        if (this.thread.title) {
          Text(this.thread.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r("app.color.text_primary"))
            .margin({ top: 12 })
            .width("100%");
        }
        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            HPRichTextV2({
              richTextModel: this.threadRichTextModel,
            })
          }
          .width("100%")
          .padding({ left: this.thread.thumbnailUrl ? 132 : 0 })

          if (this.thread.thumbnailUrl) {
            PostImage({ post: this.thread, imageWidth: 120, imageHeight: 120 });
          }
        }
        .width("100%")
        .margin({ top: 12 })
        Row() {
          Text(`回复: ${this.thread.totalReplyCount}`)
            .fontSize(14)
            .fontColor($r("app.color.text_secondary"))
          Blank()
          Text(`第 ${this.currentPage}/${this.totalPages} 页`)
            .fontSize(14)
            .fontColor($r("app.color.text_secondary"))
        }
        .width("100%")
        .margin({ top: 16 })
      }
      .width("100%")
      .padding(16)
      .backgroundColor($r("app.color.card_background"));
    }
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r("sys.symbol.arrow_left"))
            .fontSize(24)
        }
        .backgroundColor("transparent")
        .width(48)
        .height(48)
        .onClick(() => {
          router.back();
        })
        Text(this.thread ? `No.${this.thread.id}` : "加载中...")
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.text_primary"))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button() {
          Text("回复")
            .fontSize(16)
            .padding(12)
            .fontColor($r("app.color.text_primary"))
        }
        .backgroundColor(Color.Transparent)
        .enabled(this.thread !== null)
        .onClick(() => {
          if (this.thread) {
            router.pushUrl({
              url: "pages/PostPage",
              params: {
                resto: String(this.thread.id),
                threadId: String(this.thread.id),
              },
            });
          }
        })
      }
      .width("100%")
      .padding({ left: 8, right: 16, top: 44, bottom: 12 })
      .backgroundColor($r("app.color.card_background"))

      if (this.errorMessage) {
        Row() {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor($r("app.color.error"))
            .textAlign(TextAlign.Center)
            .width("100%")
        }
        .width("100%")
        .padding(16)
        .backgroundColor($r("app.color.card_background"))
        .margin({ top: 8 });
      }

      if (this.isLoading && !this.thread) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r("app.color.primary"))
          Text("加载中...")
            .fontSize(14)
            .fontColor($r("app.color.text_secondary"))
            .margin({ top: 16 })
        }
        .width("100%")
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.thread) {
        List({ scroller: this.scroller }) {
          ListItem() {
            this.threadHeader()
          }
          ForEach(this.thread.replies, (reply: Post) => {
            ListItem() {
              ReplyItem({ reply: reply })
            }
            .margin({ top: 8, left: 12, right: 12 });
          })

          if (this.hasMoreReplies()) {
            ListItem() {
              Row() {
                if (this.isLoadingMore) {
                  LoadingProgress().width(24).height(24).color($r("app.color.primary"));
                } else {
                  Button("加载更多回复")
                    .fontSize(14)
                    .fontColor($r("app.color.primary"))
                    .backgroundColor("transparent")
                    .onClick(() => {
                      this.loadThread(this.threadId, this.currentPage + 1);
                    });
                }
              }
              .width("100%")
              .height(60)
              .justifyContent(FlexAlign.Center)
            };
          }
        }
        .width("100%")
        .layoutWeight(1)
        .backgroundColor($r("app.color.background"))
        .padding({ bottom: 8 });
      }
    }
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }
}
