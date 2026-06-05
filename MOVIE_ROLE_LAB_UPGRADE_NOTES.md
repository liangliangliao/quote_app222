# 电影角色实验室升级说明

本次升级目标：解决“电影剧本由 AI 直接生成，导致与真实电影剧本严重不一致”的问题。

## 已完成

1. 新增电影角色实验室专用配置页
   - 路径：`lib/movie_role_lab/movie_role_lab_settings_page.dart`
   - 设置页入口：`lib/pages/settings_page.dart`
   - 模块首页右上角设置入口：`lib/movie_role_lab/movie_role_lab_home_page.dart`
   - 配置项：TMDb Read Access Token、TMDb API Key、OpenSubtitles API Key、用户名、密码、User-Agent、字幕语言优先级。

2. 新增配置存储层
   - 路径：`lib/movie_role_lab/movie_role_lab_config.dart`
   - TMDb Read Access Token 兼容原 `ConfigDao.movie_token`。
   - 其余模块配置通过 `KeyValueDao` 存储。

3. 新增 OpenSubtitles + SRT 解析服务
   - 路径：`lib/movie_role_lab/movie_role_lab_subtitle_service.dart`
   - 支持：按 IMDb/TMDb 搜索字幕、登录、创建下载链接、下载字幕文本、解析 SRT 时间轴、抽取真实字幕证据片段。

4. 改造 TMDb 服务
   - 路径：`lib/services/tmdb_service.dart`
   - 支持 v4 Read Access Token 与 v3 API Key 两种认证方式。
   - 新增 `/movie/{id}/external_ids` 获取 IMDb ID，用于精确匹配字幕。

5. 改造电影角色实验室业务逻辑
   - 路径：`lib/movie_role_lab/movie_role_lab_service.dart`
   - 旧逻辑：AI 直接生成进入场景与对戏内容。
   - 新逻辑：先取 TMDb 外部 ID，再取 OpenSubtitles 字幕，再解析 SRT，最后把真实字幕证据传给 AI。
   - AI 调用增加强制规则：不得编造电影剧本，不得把模拟回应伪装成原片台词。

6. 改造 UI 展示
   - 路径：`lib/movie_role_lab/movie_role_lab_entry_page.dart`
   - 角色进入页新增“真实字幕依据”卡片，显示字幕来源、语言、状态和部分真实字幕片段。
   - 对戏页会在开场显示字幕证据状态。

7. 更新默认提示词
   - 路径：`lib/services/global_ai_settings.dart`
   - 电影角色实验室默认提示词新增 `{{subtitle_evidence_json}}` 自动参数与真实字幕约束。
   - 路径：`lib/pages/ai_prompt_settings_page.dart`
   - 提示词配置中心同步展示 `{{subtitle_evidence_json}}` 参数说明。

8. 移除源码中的 TMDb 默认硬编码 Token
   - 路径：`lib/data/dao.dart`
   - `getMovieToken()` 不再返回源码内置 token；未配置时返回空字符串，避免继续依赖硬编码密钥。

## 当前边界

1. 第一版优先支持 SRT 字幕解析。
2. 普通 SRT 通常没有说话人字段，所以系统不会断言某句台词属于某个角色，只会提示“可能/无法确认”。
3. 如果 OpenSubtitles 未找到字幕，AI 只能给练习框架，不能输出所谓真实剧本。
4. 暂未做完整本地字幕全文搜索库；当前先把真实字幕片段作为 AI 证据输入，后续可继续扩展 Room/FTS 字幕搜索。
