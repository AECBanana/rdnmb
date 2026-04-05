import router from "@ohos.router";
import { AnoBBSClient } from "../api/Client";
import { ThreadPage, Post } from "../models/Post";
import { ReplyItem } from "../components/ReplyItem";
import { PostImage } from "../components/PostImage";
import { RequiresLoginException } from "../models/Errors";
import { HPRichTextV2, RichTextOptionModelV2 } from "@ohasasugar/hp-richtext";
import { ThreadReadPosition } from "../utils/CacheManager";
import { CacheManager } from "../utils/CacheManager";
import { ReplySheet } from "../components/ReplySheet";
import { SettingsManager } from "../utils/SettingsManager";
import { FavoriteThread } from "../models/FavoriteThread";
import common from "@ohos.app.ability.common";
import { pasteboard } from "@kit.BasicServicesKit";

interface ThreadPageParams {
  threadId?: number;
}

interface LinkPressEvent {
  href?: string;
  text?: string;
}

interface ContentSegment {
  type: "text" | "spoiler";
  content: string;
}

@Component
struct SpoilerText {
  @Prop text: string = "";

  build() {
    Text(this.text)
      .fontSize($r("app.float.content_text_font"))
      .fontColor($r("app.color.spoiler_bg"))
      .backgroundColor($r("app.color.spoiler_bg"))
      .borderRadius(2)
      .padding({ left: 2, right: 2 })
      .onClick(() => {
        AlertDialog.show({
          message: this.text,
          alignment: DialogAlignment.Center,
          primaryButton: {
            value: "关闭",
            action: () => {},
          },
        });
      });
  }
}

@CustomDialog
struct JumpPageDialog {
  controller: CustomDialogController;
  @Prop currentPage: number = 1;
  @Prop totalPages: number = 1;
  @State inputPage: string = "";
  onJump: (page: number) => void = () => {};

  build() {
    Column() {
      Text("跳转页数")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })
      Text(`当前第 ${this.currentPage} 页，共 ${this.totalPages} 页`)
        .fontSize(14)
        .fontColor($r("app.color.text_secondary"))
        .margin({ bottom: 16 })
      TextInput({ text: $$this.inputPage, placeholder: "输入页数" })
        .type(InputType.Number)
        .maxLength(this.totalPages)
        .width("100%")
        .height(44)
        .margin({ bottom: 16 })
      Row() {
        Button("取消")
          .width("45%")
          .height(40)
          .fontColor($r("app.color.text_primary"))
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.controller.close();
          })
        Button("跳转")
          .width("45%")
          .height(40)
          .backgroundColor($r("app.color.primary"))
          .onClick(() => {
            const page: number = parseInt(this.inputPage);
            if (page >= 1 && page <= this.totalPages) {
              this.onJump(page);
              this.controller.close();
            }
          })
      }
      .width("100%")
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .padding(20)
    .margin(16)
    .backgroundColor($r("app.color.card_background"))
    .borderRadius(16);
  }
}

@Entry
@Component
struct ThreadDetailPage {
  @State thread: ThreadPage | null = null;
  @State replies: Post[] = [];
  @State isLoading: boolean = true;
  @State isLoadingMore: boolean = false;
  @State isLoadingPrevious: boolean = false;
  @State isRefreshing: boolean = false;
  @State errorMessage: string = "";
  @State currentPage: number = 1;
  @State totalPages: number = 1;
  @State minLoadedPage: number = 1;
  @State maxLoadedPage: number = 1;
  @State threadId: number = 0;
  @State replyCount: number = 0;
  @State savedReadPage: number = 1;
  @State savedLastReplyId: number = 0;
  @State shouldScrollToReply: boolean = false;
  @State showReplySheet: boolean = false;
  @State isAtTop: boolean = false;
  @State overscrollOffset: number = 0;
  @State replyToId: string = "";
  @State highlightedReplyId: number = 0;
  @State isFavorite: boolean = false;

  private client: AnoBBSClient = new AnoBBSClient();
  private scroller: Scroller = new Scroller();
  private static readonly REPLIES_PER_PAGE: number = 20;
  private threadRichTextModel: RichTextOptionModelV2 = new RichTextOptionModelV2();
  private visibleEndIndex: number = 0;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private settingsManager: SettingsManager = SettingsManager.getInstance();
  private jumpPageDialogController: CustomDialogController | null = null;
  private threadContentSegments: ContentSegment[] = [];

  aboutToAppear() {
    const params = router.getParams() as ThreadPageParams;
    if (params && params.threadId) {
      this.threadId = params.threadId;
    }
    this.isFavorite = this.settingsManager.isThreadFavorite(this.threadId);
    this.threadRichTextModel.richTextOption = {
      content: "",
      baseFontSize: $r("app.float.content_text_font"),
      baseFontColor: $r("app.color.text_primary"),
    };
    this.threadRichTextModel.onLinkPress = (e: LinkPressEvent): LinkPressEvent => {
      console.info(`[ThreadPage] Link pressed: ${JSON.stringify(e)}`);
      let url: string | undefined = undefined;
      if (e !== null && e !== undefined) {
        if (e.href !== undefined) {
          url = e.href;
        } else if (e.text !== undefined) {
          const text: string = e.text;
          const urlMatch: RegExpMatchArray | null = text.match(/https?:\/\/[^\s`]+/);
          if (urlMatch !== null && urlMatch.length > 0) {
            url = urlMatch[0];
          }
        }
      }
      if (url !== undefined) {
        this.openLink(url);
      }
      return e;
    };
  }

  processContent(rawContent: string): string {
    let content: string = rawContent.replace(/\\n/g, "").replace(/\n/g, "");
    content = this.convertUrlsToLinks(content);
    return content;
  }

  convertUrlsToLinks(content: string): string {
    const urlPattern: RegExp = /(https?:\/\/[^\s<>"']+)/g;
    return content.replace(urlPattern, '<a href="$1">$1</a>');
  }

  splitContentBySpoilers(content: string): ContentSegment[] {
    const segments: ContentSegment[] = [];
    const spoilerPattern: RegExp = /\[h\]([\s\S]*?)\[\/h\]/g;
    let lastIndex: number = 0;
    let match: RegExpExecArray | null = null;

    while ((match = spoilerPattern.exec(content)) !== null) {
      if (match.index > lastIndex) {
        segments.push({
          type: "text",
          content: content.substring(lastIndex, match.index),
        });
      }
      segments.push({
        type: "spoiler",
        content: match[1],
      });
      lastIndex = match.index + match[0].length;
    }

    if (lastIndex < content.length) {
      segments.push({
        type: "text",
        content: content.substring(lastIndex),
      });
    }

    return segments;
  }

  hasSpoiler(): boolean {
    for (const segment of this.threadContentSegments) {
      if (segment.type === "spoiler") {
        return true;
      }
    }
    return false;
  }

  getRichTextModelForText(text: string): RichTextOptionModelV2 {
    const model: RichTextOptionModelV2 = new RichTextOptionModelV2();
    let displayContent: string = this.processContent(text);
    model.richTextOption = {
      content: displayContent,
      baseFontSize: $r("app.float.content_text_font"),
      baseFontColor: $r("app.color.text_primary"),
    };
    model.onLinkPress = (e: LinkPressEvent): LinkPressEvent => {
      let url: string | undefined = undefined;
      if (e !== null && e !== undefined) {
        if (e.href !== undefined) {
          url = e.href;
        } else if (e.text !== undefined) {
          const text: string = e.text;
          const urlMatch: RegExpMatchArray | null = text.match(/https?:\/\/[^\s`]+/);
          if (urlMatch !== null && urlMatch.length > 0) {
            url = urlMatch[0];
          }
        }
      }
      if (url !== undefined) {
        this.openLink(url);
      }
      return e;
    };
    return model;
  }

  async openLink(url: string) {
    try {
      await this.context.openLink(url);
      console.info(`[ThreadPage] Opened link: ${url}`);
    } catch (error) {
      console.error(`[ThreadPage] Failed to open link: ${error}`);
    }
  }

  async onPageShow() {
    if (this.threadId > 0 && this.thread === null) {
      const position: ThreadReadPosition | null = await this.client.getThreadReadPosition(
        this.threadId,
      );
      if (position !== null) {
        this.savedReadPage = position.page;
        this.savedLastReplyId = position.lastReplyId;
        this.shouldScrollToReply = position.lastReplyId > 0;
        console.info(
          `[ThreadPage] Restored read position: page ${position.page}, lastReplyId ${position.lastReplyId}`,
        );
      } else {
        this.savedReadPage = 1;
        this.savedLastReplyId = 0;
        this.shouldScrollToReply = false;
      }
      this.loadThread(this.threadId, this.savedReadPage);
    }
  }

  aboutToDisappear() {
    if (this.threadId > 0 && this.replies.length > 0 && this.visibleEndIndex > 0) {
      const headerOffset: number = this.isLoadingPrevious ? 2 : 1;
      const replyIndex: number = this.visibleEndIndex - headerOffset;
      if (replyIndex >= 0 && replyIndex < this.replies.length) {
        const visibleReply: Post = this.replies[replyIndex];
        const replyId: number = visibleReply.id;
        const replyPage: number =
          this.minLoadedPage + Math.floor(replyIndex / ThreadDetailPage.REPLIES_PER_PAGE);
        this.client.setThreadReadPosition(this.threadId, replyPage, replyId);
        console.info(`[ThreadPage] Saved read position: page ${replyPage}, lastReplyId ${replyId}`);
      }
    }
  }

  updateThreadRichTextModel(): void {
    if (this.thread) {
      let content: string = this.thread.content.replace(/\\n/g, "").replace(/\n/g, "");
      this.threadContentSegments = this.splitContentBySpoilers(content);
      let textContent: string = "";
      for (const segment of this.threadContentSegments) {
        if (segment.type === "text") {
          textContent += segment.content;
        }
      }
      let displayContent: string = this.processContent(textContent);
      this.threadRichTextModel.richTextOption = {
        content: displayContent,
        baseFontSize: $r("app.float.content_text_font"),
        baseFontColor: $r("app.color.text_primary"),
      };
    }
  }

  async loadThread(threadId: number, page: number) {
    this.isLoading = true;
    this.errorMessage = "";

    try {
      const thread = await this.client.getThreadPage(threadId, page);
      this.thread = thread;
      this.replies = thread.replies;
      this.calculateTotalPages(thread.totalReplyCount);
      this.updateThreadRichTextModel();
      this.currentPage = page;
      this.minLoadedPage = page;
      this.maxLoadedPage = page;
      this.replyCount = this.replies.length;
      this.visibleEndIndex = this.replies.length;
    } catch (error) {
      if (error instanceof RequiresLoginException) {
        this.errorMessage = "需要饼干才能访问，请在设置中添加饼干";
      } else {
        const errorMsg = error instanceof Error ? error.message : String(error);
        this.errorMessage = `加载失败: ${errorMsg}`;
      }
    } finally {
      this.isLoading = false;
      if (this.shouldScrollToReply && this.savedLastReplyId > 0) {
        this.scrollToReply(this.savedLastReplyId);
        this.shouldScrollToReply = false;
      }
    }
  }

  async refreshThread() {
    if (this.thread === null) {
      return;
    }
    this.isRefreshing = true;

    try {
      const thread = await this.client.getThreadPage(
        this.threadId,
        this.maxLoadedPage,
        undefined,
        true,
      );
      this.thread = thread;
      this.calculateTotalPages(thread.totalReplyCount);
      this.updateThreadRichTextModel();
      this.replies = thread.replies;
      this.minLoadedPage = this.maxLoadedPage;
      this.replyCount = this.replies.length;
      console.info(`[ThreadPage] Refreshed thread ${this.threadId}`);
    } catch (error) {
      console.error(`[ThreadPage] Failed to refresh thread: ${error}`);
    } finally {
      this.isRefreshing = false;
    }
  }

  async loadPreviousPage() {
    if (this.minLoadedPage <= 1 || this.isLoadingPrevious || this.thread === null) {
      return;
    }
    this.isLoadingPrevious = true;
    const prevPage = this.minLoadedPage - 1;

    try {
      const thread = await this.client.getThreadPage(this.threadId, prevPage);
      const newReplies = thread.raw.Replies;
      if (newReplies !== undefined && newReplies !== null) {
        const addedPosts: Post[] = [];
        for (let i = 0; i < newReplies.length; i++) {
          addedPosts.push(new Post(newReplies[i]));
        }
        const addedCount: number = addedPosts.length;
        this.replies = [...addedPosts, ...this.replies];
        this.minLoadedPage = prevPage;
        this.replyCount = this.replies.length;
        this.visibleEndIndex = this.visibleEndIndex + addedCount;
        console.info(`[ThreadPage] Loaded previous page ${prevPage}`);
      }
    } catch (error) {
      console.error(`[ThreadPage] Failed to load previous page: ${error}`);
    } finally {
      this.isLoadingPrevious = false;
    }
  }

  async loadNextPage() {
    if (this.maxLoadedPage >= this.totalPages || this.isLoadingMore || this.thread === null) {
      return;
    }
    this.isLoadingMore = true;
    const nextPage = this.maxLoadedPage + 1;

    try {
      const thread = await this.client.getThreadPage(this.threadId, nextPage);
      const newReplies = thread.raw.Replies;
      if (newReplies !== undefined && newReplies !== null) {
        for (let i = 0; i < newReplies.length; i++) {
          this.replies.push(new Post(newReplies[i]));
        }
        this.maxLoadedPage = nextPage;
        this.replyCount = this.replies.length;
        console.info(`[ThreadPage] Loaded next page ${nextPage}`);
      }
    } catch (error) {
      console.error(`[ThreadPage] Failed to load next page: ${error}`);
    } finally {
      this.isLoadingMore = false;
    }
  }

  async onReplySuccess(replyId: string) {
    console.info(`[ThreadPage] Reply success: ${replyId}`);
    const wasAtLastPage: boolean = this.maxLoadedPage >= this.totalPages;
    await this.refreshThread();
    if (this.thread !== null) {
      CacheManager.getInstance().setThreadCache(this.threadId, this.maxLoadedPage, this.thread);
      console.info(
        `[ThreadPage] Updated cache for thread ${this.threadId} page ${this.maxLoadedPage}`,
      );
    }
    if (wasAtLastPage) {
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 100);
    }
  }

  scrollToReply(replyId: number): void {
    for (let i = 0; i < this.replies.length; i++) {
      if (this.replies[i].id === replyId) {
        const targetIndex = i + 1;
        setTimeout(() => {
          this.scroller.scrollToIndex(targetIndex, false, ScrollAlign.CENTER);
          console.info(`[ThreadPage] Scrolled to reply ${replyId} at index ${targetIndex}`);
        }, 100);
        return;
      }
    }
    console.info(`[ThreadPage] Reply ${replyId} not found in loaded replies`);
  }

  calculateTotalPages(totalReplies: number): void {
    if (totalReplies <= 0) {
      this.totalPages = 1;
    } else {
      this.totalPages = Math.ceil(totalReplies / ThreadDetailPage.REPLIES_PER_PAGE);
    }
  }

  hasPreviousPage(): boolean {
    return this.minLoadedPage > 1;
  }

  hasNextPage(): boolean {
    return this.maxLoadedPage < this.totalPages;
  }

  jumpToReply(replyId: string): void {
    const targetId: number = parseInt(replyId);
    console.info(`[ThreadPage] Jump to reply: ${targetId}`);

    for (let i = 0; i < this.replies.length; i++) {
      if (this.replies[i].id === targetId) {
        console.info(`[ThreadPage] Found reply at index: ${i}`);
        this.scroller.scrollToIndex(i + 1, true, ScrollAlign.CENTER);
        this.highlightedReplyId = targetId;

        setTimeout(() => {
          this.highlightedReplyId = 0;
        }, 1500);
        return;
      }
    }

    console.info(`[ThreadPage] Reply ${targetId} not found in current page`);
    this.getUIContext().showAlertDialog({
      message: `回复 No.${targetId} 不在当前页面`,
    });
  }

  @Builder
  threadMenuBuilder() {
    Menu() {
      MenuItem({
        content: this.isFavorite ? "󰀉 取消收藏" : "󰁎 收藏",
      })
        .onClick(() => {
          this.toggleFavorite();
        })
      MenuItem({
        content: "󰁬 回复",
      })
        .onClick(() => {
          if (this.thread) {
            this.replyToId = "";
            this.showReplySheet = true;
          }
        })
      MenuItem({
        content: "󰢨 跳转页数",
      })
        .onClick(() => {
          this.jumpPageDialogController = new CustomDialogController({
            builder: JumpPageDialog({
              currentPage: this.currentPage,
              totalPages: this.totalPages,
              onJump: (page: number) => {
                this.jumpToPage(page);
              },
            }),
            customStyle: true,
            alignment: DialogAlignment.Center,
          });
          this.jumpPageDialogController.open();
        })
    };
  }

  jumpToPage(page: number): void {
    if (page === this.currentPage) {
      return;
    }
    this.replies = [];
    this.currentPage = page;
    this.minLoadedPage = page;
    this.maxLoadedPage = page;
    this.loadThread(this.threadId, page);
  }

  async toggleFavorite() {
    if (!this.thread) {
      return;
    }
    const favorite: FavoriteThread = new FavoriteThread({
      id: this.thread.id,
      title: this.thread.title || "",
      content: this.thread.content,
      thumbnailUrl: this.thread.thumbnailUrl,
      userId: this.thread.userId,
      createdAt: this.thread.createdAtText,
      savedAt: Date.now(),
      fid: this.thread.boardId,
      replyCount: this.thread.totalReplyCount,
    });
    this.isFavorite = await this.settingsManager.toggleFavoriteThread(favorite);
    console.info(`[ThreadPage] Toggled favorite: ${this.threadId}, isFavorite: ${this.isFavorite}`);
  }

  @Builder
  threadContentMenuBuilder() {
    Menu() {
      MenuItem({
        content: "󰆊 复制内容",
      })
        .onClick(() => {
          this.copyThreadContent();
        })
    };
  }

  copyThreadContent(): void {
    if (!this.thread) {
      return;
    }
    const rawContent: string = this.thread.content;
    const cleanContent: string = rawContent.replace(/\\n/g, "\n").replace(/<br\s*\/?>/gi, "\n");
    const pasteboardData: pasteboard.PasteData = pasteboard.createData(
      pasteboard.MIMETYPE_TEXT_PLAIN,
      cleanContent,
    );
    const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteboardData);
    console.info(`[ThreadPage] Thread content copied to clipboard`);
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
            .margin({ left: 8 })
          Text(this.thread.createdAtText)
            .fontSize(12)
            .fontColor($r("app.color.text_secondary"))
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
            if (this.hasSpoiler()) {
              Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Start }) {
                ForEach(this.threadContentSegments, (segment: ContentSegment, index: number) => {
                  if (segment.type === "text") {
                    HPRichTextV2({
                      richTextModel: this.getRichTextModelForText(segment.content),
                    });
                  } else {
                    SpoilerText({ text: segment.content });
                  }
                })
              }.width("100%");
            } else {
              HPRichTextV2({
                richTextModel: this.threadRichTextModel,
              });
            }
          }
          .width("100%")
          .padding({ left: this.thread.thumbnailUrl ? 132 : 0 })

          if (this.thread.thumbnailUrl) {
            PostImage({ post: this.thread, imageWidth: 120, imageHeight: 120 });
          }
        }
        .width("100%")
        .margin({ top: 12 })
        .bindContextMenu(
          this.threadContentMenuBuilder,
          ResponseType.LongPress | ResponseType.RightClick,
        )
        Row() {
          Text(`回复: ${this.thread.totalReplyCount}`)
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
            .fontColor([$r("app.color.text_secondary")])
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
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r("sys.symbol.dot_grid_2x2"))
            .fontSize(24)
            .fontColor([$r("app.color.text_secondary")])
        }
        .backgroundColor("transparent")
        .width(48)
        .height(48)
        .enabled(this.thread !== null)
        .bindMenu(this.threadMenuBuilder)
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
        .justifyContent(FlexAlign.Center);
      } else if (this.thread) {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ scroller: this.scroller }) {
            if (this.isLoadingPrevious) {
              ListItem() {
                Row() {
                  LoadingProgress()
                    .width(24)
                    .height(24)
                    .color($r("app.color.primary"))
                  Text("加载上一页...")
                    .fontSize(14)
                    .fontColor($r("app.color.text_secondary"))
                    .margin({ left: 8 })
                }
                .width("100%")
                .height(60)
                .justifyContent(FlexAlign.Center)
              };
            }
            ListItem() {
              this.threadHeader()
            }
            ForEach(this.replies, (reply: Post) => {
              ListItem() {
                ReplyItem({
                  reply: reply,
                  threadUserid: this.thread?.userId ?? "",
                  isHighlighted: this.highlightedReplyId === reply.id,
                  onReplyClick: (replyId: string) => {
                    this.replyToId = replyId;
                    this.showReplySheet = true;
                  },
                  onJumpToReply: (replyId: string) => {
                    this.jumpToReply(replyId);
                  },
                })
              }
              .margin({ top: 8, left: 12, right: 12 });
            })

            if (this.isLoadingMore) {
              ListItem() {
                Row() {
                  LoadingProgress()
                    .width(24)
                    .height(24)
                    .color($r("app.color.primary"))
                  Text("加载下一页...")
                    .fontSize(14)
                    .fontColor($r("app.color.text_secondary"))
                    .margin({ left: 8 })
                }
                .width("100%")
                .height(60)
                .justifyContent(FlexAlign.Center)
              };
            }
          }
          .width("100%")
          .height("100%")
          .layoutWeight(1)
          .chainAnimation(true)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .backgroundColor($r("app.color.background"))
          .padding({ bottom: 8 })
          .onScrollIndex((start: number, end: number) => {
            this.visibleEndIndex = end;
            this.isAtTop = start === 0;
          })
          .onScrollFrameBegin((offset: number) => {
            if (this.isAtTop && offset < 0) {
              this.overscrollOffset = this.overscrollOffset + -offset;
              if (
                this.overscrollOffset >= 64 &&
                this.hasPreviousPage() &&
                !this.isLoadingPrevious &&
                !this.isLoading
              ) {
                this.overscrollOffset = 0;
                this.loadPreviousPage();
              }
            } else {
              this.overscrollOffset = 0;
            }
            return { offsetRemain: offset };
          })
          .onReachEnd(() => {
            if (this.hasNextPage() && !this.isLoadingMore && !this.isLoading) {
              this.loadNextPage();
            }
          })
        }
        .width("100%")
        .layoutWeight(1)
        .refreshOffset(64)
        .onRefreshing(() => {
          if (this.minLoadedPage === 1) {
            this.refreshThread();
          } else {
            this.isRefreshing = false;
          }
        });
      }
    }
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .bindSheet($$this.showReplySheet, this.replySheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      backgroundColor: Color.Transparent,
      onDisappear: () => {
        this.showReplySheet = false;
        this.replyToId = "";
      },
    });
  }

  @Builder
  replySheetBuilder() {
    ReplySheet({
      resto: String(this.threadId),
      threadId: String(this.threadId),
      replyToId: this.replyToId,
      isShow: $showReplySheet,
      onReplySuccess: (replyId: string) => {
        this.onReplySuccess(replyId);
      },
    });
  }
}
