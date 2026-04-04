import { AnoBBSClient } from "../api/Client";
import { BoardThread } from "../models/Post";
import { Community, Timeline, Forum } from "../models/Forum";
import { ThreadListItem } from "../components/ThreadListItem";
import { RequiresLoginException } from "../models/Errors";
import { CookieManager } from "../utils/CookieManager";
import { SettingsManager } from "../utils/SettingsManager";
import { PostSheet } from "../components/PostSheet";

interface BoardInfo {
  id: number;
  name: string;
  isTimeline: boolean;
}

@Entry
@Component
struct BoardListPage {
  @State threads: BoardThread[] = [];
  @State isLoading: boolean = false;
  @State isLoadingMore: boolean = false;
  @State isRefreshing: boolean = false;
  @State errorMessage: string = "";
  @State currentPage: number = 1;
  @State currentBoardId: number = -1;
  @State currentBoardName: string = "时间线";
  @State isCurrentTimeline: boolean = true;
  @State showBoardDrawer: boolean = false;
  @State communities: Community[] = [];
  @State timelines: Timeline[] = [];
  @State boardsLoading: boolean = true;
  @State hasMore: boolean = true;
  @State readAnnouncementIds: number[] = [];
  @State showPostSheet: boolean = false;

  private client: AnoBBSClient = new AnoBBSClient();
  private scroller: Scroller = new Scroller();
  private cookieManager: CookieManager = CookieManager.getInstance();
  private settingsManager: SettingsManager = SettingsManager.getInstance();
  private static readonly ADMIN_ANNOUNCEMENT_THREAD_ID: number = 52752005;

  async aboutToAppear() {
    console.info("[BoardListPage] aboutToAppear: waiting for managers init...");
    await this.cookieManager.waitForInit();
    await this.settingsManager.waitForInit();
    this.readAnnouncementIds = this.settingsManager.getReadAnnouncementIds();
    console.info("[BoardListPage] Managers init completed, loading forums...");
    await this.loadForumsAndTimelines();
    console.info("[BoardListPage] Forums loaded, loading board threads...");
    await this.loadBoardThreads(this.currentBoardId);
  }

  async loadForumsAndTimelines() {
    this.boardsLoading = true;
    try {
      const results = await Promise.all([
        this.client.getForumList(),
        this.client.getTimelineList(),
      ]);
      this.communities = results[0];
      this.timelines = results[1];
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error(`加载版块列表失败: ${errorMsg}`);
    } finally {
      this.boardsLoading = false;
    }
  }

  async loadBoardThreads(boardId: number, page: number = 1) {
    console.info(`[BoardListPage] loadBoardThreads: boardId=${boardId}, page=${page}`);

    if (page === 1) {
      const cached = await this.client.getBoardCache(boardId, page);
      console.info(`[BoardListPage] getBoardCache result: ${cached !== null ? "found" : "null"}`);

      if (cached !== null && cached.threads && Array.isArray(cached.threads)) {
        console.info(`[BoardListPage] Using cached board threads`);
        this.threads = this.filterReadAnnouncements(cached.threads);
        this.currentPage = 1;
        this.isLoading = false;
        this.hasMore = cached.threads.length > 0;
        this.scroller.scrollToIndex(0, true);
        return;
      }
    }

    await this.fetchBoardThreads(boardId, page);
  }

  async refreshBoardThreads() {
    console.info(`[BoardListPage] refreshBoardThreads: boardId=${this.currentBoardId}`);
    this.readAnnouncementIds = this.settingsManager.getReadAnnouncementIds();
    try {
      const threads = await this.client.getBoardPage(this.currentBoardId, 1);
      this.threads = this.filterReadAnnouncements(threads);
      this.currentPage = 1;
      this.hasMore = threads.length > 0;
      this.errorMessage = "";
      this.scroller.scrollToIndex(0, false);
    } catch (error) {
      if (error instanceof RequiresLoginException) {
        this.errorMessage = "需要饼干才能访问，请在设置中添加饼干";
      } else {
        const errorMsg = error instanceof Error ? error.message : String(error);
        this.errorMessage = `加载失败: ${errorMsg}`;
      }
    } finally {
      this.isRefreshing = false;
    }
  }

  async fetchBoardThreads(boardId: number, page: number) {
    if (page === 1) {
      this.isLoading = true;
    } else {
      this.isLoadingMore = true;
    }

    this.errorMessage = "";
    try {
      const threads = await this.client.getBoardPage(boardId, page);
      if (page === 1) {
        this.threads = this.filterReadAnnouncements(threads);
        this.scroller.scrollToIndex(0, false);
      } else {
        this.threads = [...this.threads, ...this.filterReadAnnouncements(threads)];
      }
      this.currentPage = page;
      this.hasMore = threads.length > 0;
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

  filterReadAnnouncements(threads: BoardThread[]): BoardThread[] {
    return threads.filter((thread: BoardThread) => {
      if (thread.id === BoardListPage.ADMIN_ANNOUNCEMENT_THREAD_ID) {
        return this.readAnnouncementIds.indexOf(thread.id) === -1;
      }
      return true;
    });
  }

  async onThreadClick(threadId: number) {
    if (threadId === BoardListPage.ADMIN_ANNOUNCEMENT_THREAD_ID) {
      await this.settingsManager.setAnnouncementRead(threadId);
      this.readAnnouncementIds = this.settingsManager.getReadAnnouncementIds();
      console.info(`[BoardListPage] Marked admin announcement ${threadId} as read`);
    }
    this.getUIContext()
      .getRouter()
      .pushUrl({
        url: "pages/ThreadPage",
        params: { threadId: threadId },
      })
      .catch(() => {
        // TODO: Implement error handling.
      });
  }

  getAllBoards(): BoardInfo[] {
    const result: BoardInfo[] = [];

    for (let i = 0; i < this.timelines.length; i++) {
      const t = this.timelines[i];
      result.push({
        id: -t.id,
        name: t.displayName,
        isTimeline: true,
      });
    }

    for (let i = 0; i < this.communities.length; i++) {
      const community = this.communities[i];
      const forums = community.forums;
      for (let j = 0; j < forums.length; j++) {
        const forum = forums[j];
        if (forum.isValid()) {
          result.push({
            id: forum.id,
            name: forum.displayName,
            isTimeline: false,
          });
        }
      }
    }

    return result;
  }

  getBoardNameMap(): Map<number, string> {
    const map: Map<number, string> = new Map();

    for (let i = 0; i < this.timelines.length; i++) {
      const t = this.timelines[i];
      map.set(-t.id, t.displayName);
    }

    for (let i = 0; i < this.communities.length; i++) {
      const community = this.communities[i];
      const forums = community.forums;
      for (let j = 0; j < forums.length; j++) {
        const forum = forums[j];
        if (forum.isValid()) {
          map.set(forum.id, forum.displayName);
        }
      }
    }

    return map;
  }

  @Builder
  moreMenuBuilder() {
    Menu() {
      MenuItem({
        content: "󰁳 发串",
      })
        .onClick(() => {
          this.showPostSheet = true;
        })
      MenuItem({
        content: "󰀠 设置",
      })
        .onClick(() => {
          this.getUIContext()
            .getRouter()
            .pushUrl({
              url: "pages/SettingsPage",
            })
            .catch(() => {
              // TODO: Implement error handling.
            });
        })
    };
  }

  @Builder
  postSheetBuilder() {
    PostSheet({
      fid: String(this.currentBoardId),
      boardName: this.currentBoardName,
      isShow: $showPostSheet,
      onPostSuccess: async (threadId: string) => {
        console.info(`[BoardListPage] New thread posted: ${threadId}`);
        await this.client.clearBoardCache(this.currentBoardId);
        await this.refreshBoardThreads();
      },
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r("sys.symbol.more"))
              .fontSize(24)
              .fontColor([$r("app.color.text_primary")])
          }
          .backgroundColor("transparent")
          .width(48)
          .height(48)
          .onClick(() => {
            this.showBoardDrawer = true;
          })
          Text(this.currentBoardName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r("app.color.text_primary"))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
            .margin({ left: 8 })
          Row() {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r("sys.symbol.ellipsis_circle"))
                .fontSize(24)
                .fontColor([$r("app.color.text_primary")])
            }
            .width(48)
            .height(48)
            .backgroundColor("transparent")
            .bindMenu(this.moreMenuBuilder)
          }
        }
        .width("100%")
        .padding({ left: 8, right: 8, top: 44, bottom: 8 })

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
          .margin(8);
        }

        if (this.isLoading && this.threads.length === 0) {
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
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ scroller: this.scroller }) {
              ForEach(this.threads, (thread: BoardThread) => {
                ListItem() {
                  ThreadListItem({
                    thread: thread,
                    boardNameMap: this.getBoardNameMap(),
                    isTimeline: this.isCurrentTimeline,
                    onItemClick: (threadId: number) => {
                      this.onThreadClick(threadId);
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
                    Text("加载中...")
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
            .height("auto")
            .layoutWeight(1)
            .borderRadius(16)
            .backgroundColor($r("app.color.background"))
            .chainAnimation(true)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .clip(true)
            .padding({ bottom: 16 })
            .onScrollIndex((end: number) => {
              if (
                this.hasMore &&
                !this.isLoadingMore &&
                !this.isLoading &&
                !this.isRefreshing &&
                end >= this.threads.length - 3
              ) {
                this.loadBoardThreads(this.currentBoardId, this.currentPage + 1);
              }
            })
          }
          .refreshOffset(64)
          .onRefreshing(() => {
            this.refreshBoardThreads();
          })
          .width("100%")
          .layoutWeight(1);
        }
      }
      .width("100%")
      .height("100%")
      .backgroundColor($r("app.color.background"))

      if (this.showBoardDrawer) {
        Column() {
          Row() {
            Column() {
              Row() {
                Text("版块列表")
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r("app.color.text_primary"))
                  .layoutWeight(1)
              }
              .width("100%")
              .padding(16)
              .margin({ top: 44 })

              if (this.boardsLoading && this.communities.length === 0) {
                Column() {
                  LoadingProgress()
                    .width(32)
                    .height(32)
                    .color($r("app.color.primary"))
                  Text("加载版块列表...")
                    .fontSize(12)
                    .fontColor($r("app.color.text_secondary"))
                    .margin({ top: 8 })
                }
                .width("100%")
                .height(200)
                .justifyContent(FlexAlign.Center);
              } else {
                List() {
                  if (this.timelines.length > 0) {
                    ListItem() {
                      Text("时间线")
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .padding(8)
                        .fontColor($r("app.color.text_secondary"))
                        .width("100%")
                        .backgroundColor($r("app.color.background"))
                    };
                  }
                  ForEach(this.timelines, (timeline: Timeline) => {
                    ListItem() {
                      Column() {
                        Text(timeline.displayName)
                          .fontSize(16)
                          .padding(8)
                          .fontColor(
                            this.currentBoardId === -timeline.id
                              ? $r("app.color.primary")
                              : $r("app.color.text_primary"),
                          )
                          .width("100%")
                          .backgroundColor(
                            this.currentBoardId === -timeline.id
                              ? $r("app.color.reply_count_bg")
                              : "transparent",
                          )
                          .borderRadius(16)
                          .onClick(() => {
                            this.currentBoardId = -timeline.id;
                            this.currentBoardName = timeline.displayName;
                            this.isCurrentTimeline = true;
                            this.showBoardDrawer = false;
                            this.loadBoardThreads(-timeline.id, 1);
                          })
                      }
                    };
                  })
                  ForEach(this.communities, (community: Community) => {
                    ListItem() {
                      Column() {
                        Text(community.name)
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor($r("app.color.text_secondary"))
                          .width("100%")
                          .padding(8)
                          .backgroundColor($r("app.color.background"))
                        ForEach(community.forums, (forum: Forum) => {
                          if (forum.isValid()) {
                            Text(forum.displayName)
                              .fontSize(16)
                              .fontColor(
                                this.currentBoardId === forum.id
                                  ? $r("app.color.primary")
                                  : $r("app.color.text_primary"),
                              )
                              .width("100%")
                              .padding(8)
                              .backgroundColor(
                                this.currentBoardId === forum.id
                                  ? $r("app.color.reply_count_bg")
                                  : "transparent",
                              )
                              .borderRadius(16)
                              .onClick(() => {
                                this.currentBoardId = forum.id;
                                this.currentBoardName = forum.displayName;
                                this.isCurrentTimeline = false;
                                this.showBoardDrawer = false;
                                this.loadBoardThreads(forum.id, 1);
                              });
                          }
                        })
                      }.width("100%")
                    };
                  })
                }
                .width("100%")
                .height("100%")
                .layoutWeight(1)
                .chainAnimation(true)
                .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
                .divider({ strokeWidth: 1, color: $r("app.color.divider") });
              }
            }
            .width(280)
            .height("100%")
            .backgroundColor($r("app.color.card_background"))
            Column()
              .layoutWeight(1)
              .height("100%")
              .backgroundColor("#80000000")
              .onClick(() => {
                this.showBoardDrawer = false;
              })
          }
          .width("100%")
          .height("100%")
        }
        .width("100%")
        .height("100%");
      }
    }
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .bindSheet($$this.showPostSheet, this.postSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      backgroundColor: Color.Transparent,
      onDisappear: () => {
        this.showPostSheet = false;
      },
    });
  }
}
