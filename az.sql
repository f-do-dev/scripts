-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- 主机： 
-- 生成日期： 2025-04-20 03:51:49
-- 服务器版本： 8.2.0
-- PHP 版本： 8.2.21

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- 数据库： `new-api-az-test`
--
CREATE DATABASE IF NOT EXISTS `new-api-az-test` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `new-api-az-test`;

-- --------------------------------------------------------

--
-- 表的结构 `abilities`
--

CREATE TABLE `abilities` (
  `group` varchar(64) COLLATE utf8mb4_general_ci NOT NULL,
  `model` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `channel_id` bigint NOT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `priority` bigint DEFAULT '0',
  `weight` bigint UNSIGNED DEFAULT '0',
  `tag` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 转存表中的数据 `abilities`
--

INSERT INTO `abilities` (`group`, `model`, `channel_id`, `enabled`, `priority`, `weight`, `tag`) VALUES
('default', 'gpt-4-1106-preview', 1, 1, 0, 0, '');

-- --------------------------------------------------------

--
-- 表的结构 `channels`
--

CREATE TABLE `channels` (
  `id` bigint NOT NULL,
  `type` bigint DEFAULT '0',
  `key` longtext COLLATE utf8mb4_general_ci NOT NULL,
  `open_ai_organization` longtext COLLATE utf8mb4_general_ci,
  `test_model` longtext COLLATE utf8mb4_general_ci,
  `status` bigint DEFAULT '1',
  `name` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `weight` bigint UNSIGNED DEFAULT '0',
  `created_time` bigint DEFAULT NULL,
  `test_time` bigint DEFAULT NULL,
  `response_time` bigint DEFAULT NULL,
  `base_url` varchar(191) COLLATE utf8mb4_general_ci DEFAULT '',
  `other` longtext COLLATE utf8mb4_general_ci,
  `balance` double DEFAULT NULL,
  `balance_updated_time` bigint DEFAULT NULL,
  `models` longtext COLLATE utf8mb4_general_ci,
  `group` varchar(64) COLLATE utf8mb4_general_ci DEFAULT 'default',
  `used_quota` bigint DEFAULT '0',
  `model_mapping` text COLLATE utf8mb4_general_ci,
  `status_code_mapping` varchar(1024) COLLATE utf8mb4_general_ci DEFAULT '',
  `priority` bigint DEFAULT '0',
  `auto_ban` bigint DEFAULT '1',
  `other_info` longtext COLLATE utf8mb4_general_ci,
  `tag` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `setting` text COLLATE utf8mb4_general_ci,
  `param_override` text COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 转存表中的数据 `channels`
--

INSERT INTO `channels` (`id`, `type`, `key`, `open_ai_organization`, `test_model`, `status`, `name`, `weight`, `created_time`, `test_time`, `response_time`, `base_url`, `other`, `balance`, `balance_updated_time`, `models`, `group`, `used_quota`, `model_mapping`, `status_code_mapping`, `priority`, `auto_ban`, `other_info`, `tag`, `setting`, `param_override`) VALUES
(1, 3, 'test', '', '', 1, 'az渠道', 0, 1745121022, 1745121045, 1212, 'https://inapi.openai.azure.com', '2025-01-01-preview', 0, 0, 'gpt-4-1106-preview', 'default', 0, '{\n  \"gpt-4-1106-preview\": \"gpt-4\"\n}', '', 0, 1, '', '', NULL, NULL);

-- --------------------------------------------------------

--
-- 表的结构 `logs`
--

CREATE TABLE `logs` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `created_at` bigint DEFAULT NULL,
  `type` bigint DEFAULT NULL,
  `content` longtext COLLATE utf8mb4_general_ci,
  `username` varchar(191) COLLATE utf8mb4_general_ci DEFAULT '',
  `token_name` varchar(191) COLLATE utf8mb4_general_ci DEFAULT '',
  `model_name` varchar(191) COLLATE utf8mb4_general_ci DEFAULT '',
  `quota` bigint DEFAULT '0',
  `prompt_tokens` bigint DEFAULT '0',
  `completion_tokens` bigint DEFAULT '0',
  `use_time` bigint DEFAULT '0',
  `is_stream` tinyint(1) DEFAULT '0',
  `channel_id` bigint DEFAULT NULL,
  `channel_name` longtext COLLATE utf8mb4_general_ci,
  `token_id` bigint DEFAULT '0',
  `group` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `other` longtext COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 转存表中的数据 `logs`
--

INSERT INTO `logs` (`id`, `user_id`, `created_at`, `type`, `content`, `username`, `token_name`, `model_name`, `quota`, `prompt_tokens`, `completion_tokens`, `use_time`, `is_stream`, `channel_id`, `channel_name`, `token_id`, `group`, `other`) VALUES
(1, 1, 1745121033, 3, '管理员将用户额度从 ＄200.000000 额度修改为 ＄2000000.000000 额度', 'az-root', '', '', 0, 0, 0, 0, 0, 0, NULL, 0, '', '');

-- --------------------------------------------------------

--
-- 表的结构 `midjourneys`
--

CREATE TABLE `midjourneys` (
  `id` bigint NOT NULL,
  `code` bigint DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  `action` varchar(40) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `mj_id` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `prompt` longtext COLLATE utf8mb4_general_ci,
  `prompt_en` longtext COLLATE utf8mb4_general_ci,
  `description` longtext COLLATE utf8mb4_general_ci,
  `state` longtext COLLATE utf8mb4_general_ci,
  `submit_time` bigint DEFAULT NULL,
  `start_time` bigint DEFAULT NULL,
  `finish_time` bigint DEFAULT NULL,
  `image_url` longtext COLLATE utf8mb4_general_ci,
  `status` varchar(20) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `progress` varchar(30) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `fail_reason` longtext COLLATE utf8mb4_general_ci,
  `channel_id` bigint DEFAULT NULL,
  `quota` bigint DEFAULT NULL,
  `buttons` longtext COLLATE utf8mb4_general_ci,
  `properties` longtext COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 表的结构 `options`
--

CREATE TABLE `options` (
  `key` varchar(191) COLLATE utf8mb4_general_ci NOT NULL,
  `value` longtext COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 转存表中的数据 `options`
--

INSERT INTO `options` (`key`, `value`) VALUES
('CheckSensitiveEnabled', 'false'),
('CheckSensitiveOnPromptEnabled', 'false'),
('DataExportEnabled', 'false'),
('DemoSiteEnabled', 'false'),
('LogConsumeEnabled', 'false'),
('RetryTimes', '3'),
('SelfUseModeEnabled', 'true');

-- --------------------------------------------------------

--
-- 表的结构 `quota_data`
--

CREATE TABLE `quota_data` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `username` varchar(64) COLLATE utf8mb4_general_ci DEFAULT '',
  `model_name` varchar(64) COLLATE utf8mb4_general_ci DEFAULT '',
  `created_at` bigint DEFAULT NULL,
  `token_used` bigint DEFAULT '0',
  `count` bigint DEFAULT '0',
  `quota` bigint DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 表的结构 `redemptions`
--

CREATE TABLE `redemptions` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `key` char(32) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `status` bigint DEFAULT '1',
  `name` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `quota` bigint DEFAULT '100',
  `created_time` bigint DEFAULT NULL,
  `redeemed_time` bigint DEFAULT NULL,
  `used_user_id` bigint DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 表的结构 `setups`
--

CREATE TABLE `setups` (
  `id` bigint UNSIGNED NOT NULL,
  `version` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `initialized_at` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 转存表中的数据 `setups`
--

INSERT INTO `setups` (`id`, `version`, `initialized_at`) VALUES
(1, 'v0.6.6.2', 1745120879);

-- --------------------------------------------------------

--
-- 表的结构 `tasks`
--

CREATE TABLE `tasks` (
  `id` bigint NOT NULL,
  `created_at` bigint DEFAULT NULL,
  `updated_at` bigint DEFAULT NULL,
  `task_id` varchar(50) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `platform` varchar(30) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  `channel_id` bigint DEFAULT NULL,
  `quota` bigint DEFAULT NULL,
  `action` varchar(40) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `status` varchar(20) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `fail_reason` longtext COLLATE utf8mb4_general_ci,
  `submit_time` bigint DEFAULT NULL,
  `start_time` bigint DEFAULT NULL,
  `finish_time` bigint DEFAULT NULL,
  `progress` varchar(20) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `properties` json DEFAULT NULL,
  `data` json DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 表的结构 `tokens`
--

CREATE TABLE `tokens` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `key` char(48) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `status` bigint DEFAULT '1',
  `name` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `created_time` bigint DEFAULT NULL,
  `accessed_time` bigint DEFAULT NULL,
  `expired_time` bigint DEFAULT '-1',
  `remain_quota` bigint DEFAULT '0',
  `unlimited_quota` tinyint(1) DEFAULT '0',
  `model_limits_enabled` tinyint(1) DEFAULT '0',
  `model_limits` varchar(1024) COLLATE utf8mb4_general_ci DEFAULT '',
  `allow_ips` varchar(191) COLLATE utf8mb4_general_ci DEFAULT '',
  `used_quota` bigint DEFAULT '0',
  `group` varchar(191) COLLATE utf8mb4_general_ci DEFAULT '',
  `deleted_at` datetime(3) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 转存表中的数据 `tokens`
--

INSERT INTO `tokens` (`id`, `user_id`, `key`, `status`, `name`, `created_time`, `accessed_time`, `expired_time`, `remain_quota`, `unlimited_quota`, `model_limits_enabled`, `model_limits`, `allow_ips`, `used_quota`, `group`, `deleted_at`) VALUES
(1, 1, 'b6rRWWbuBUo2rAf8aFn1KiRtr7wZC3w3TsyO0oaGcnBHSr1s', 1, '', 1745121047, 1745121047, -1, 500000000000, 0, 0, '', '', 0, '', NULL);

-- --------------------------------------------------------

--
-- 表的结构 `top_ups`
--

CREATE TABLE `top_ups` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `amount` bigint DEFAULT NULL,
  `money` double DEFAULT NULL,
  `trade_no` longtext COLLATE utf8mb4_general_ci,
  `create_time` bigint DEFAULT NULL,
  `status` longtext COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 表的结构 `users`
--

CREATE TABLE `users` (
  `id` bigint NOT NULL,
  `username` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `password` longtext COLLATE utf8mb4_general_ci NOT NULL,
  `display_name` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `role` bigint DEFAULT '1',
  `status` bigint DEFAULT '1',
  `email` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `github_id` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `oidc_id` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `wechat_id` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `telegram_id` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `access_token` char(32) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `quota` bigint DEFAULT '0',
  `used_quota` bigint DEFAULT '0',
  `request_count` bigint DEFAULT '0',
  `group` varchar(64) COLLATE utf8mb4_general_ci DEFAULT 'default',
  `aff_code` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `aff_count` bigint DEFAULT '0',
  `aff_quota` bigint DEFAULT '0',
  `aff_history` bigint DEFAULT '0',
  `inviter_id` bigint DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `linux_do_id` varchar(191) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `setting` text COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 转存表中的数据 `users`
--

INSERT INTO `users` (`id`, `username`, `password`, `display_name`, `role`, `status`, `email`, `github_id`, `oidc_id`, `wechat_id`, `telegram_id`, `access_token`, `quota`, `used_quota`, `request_count`, `group`, `aff_code`, `aff_count`, `aff_quota`, `aff_history`, `inviter_id`, `deleted_at`, `linux_do_id`, `setting`) VALUES
(1, 'az-root', '$2a$10$n6Xy5XXb2Ie7SbxDialdJuu/YsM1SI4714LCVybDkK/UgnzzwbtSy', 'Root User', 100, 1, '', '', '', '', '', NULL, 1000000000000, 0, 0, 'default', 'KaUP', 0, 0, 0, 0, NULL, '', '');

--
-- 转储表的索引
--

--
-- 表的索引 `abilities`
--
ALTER TABLE `abilities`
  ADD PRIMARY KEY (`group`,`model`,`channel_id`),
  ADD KEY `idx_abilities_channel_id` (`channel_id`),
  ADD KEY `idx_abilities_priority` (`priority`),
  ADD KEY `idx_abilities_weight` (`weight`),
  ADD KEY `idx_abilities_tag` (`tag`);

--
-- 表的索引 `channels`
--
ALTER TABLE `channels`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_channels_name` (`name`),
  ADD KEY `idx_channels_tag` (`tag`);

--
-- 表的索引 `logs`
--
ALTER TABLE `logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_logs_user_id` (`user_id`),
  ADD KEY `index_username_model_name` (`model_name`,`username`),
  ADD KEY `idx_logs_model_name` (`model_name`),
  ADD KEY `idx_logs_channel_id` (`channel_id`),
  ADD KEY `idx_logs_token_id` (`token_id`),
  ADD KEY `idx_logs_group` (`group`),
  ADD KEY `idx_created_at_id` (`id`,`created_at`),
  ADD KEY `idx_created_at_type` (`created_at`,`type`),
  ADD KEY `idx_logs_username` (`username`),
  ADD KEY `idx_logs_token_name` (`token_name`);

--
-- 表的索引 `midjourneys`
--
ALTER TABLE `midjourneys`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_midjourneys_action` (`action`),
  ADD KEY `idx_midjourneys_mj_id` (`mj_id`),
  ADD KEY `idx_midjourneys_submit_time` (`submit_time`),
  ADD KEY `idx_midjourneys_start_time` (`start_time`),
  ADD KEY `idx_midjourneys_finish_time` (`finish_time`),
  ADD KEY `idx_midjourneys_status` (`status`),
  ADD KEY `idx_midjourneys_progress` (`progress`),
  ADD KEY `idx_midjourneys_user_id` (`user_id`);

--
-- 表的索引 `options`
--
ALTER TABLE `options`
  ADD PRIMARY KEY (`key`);

--
-- 表的索引 `quota_data`
--
ALTER TABLE `quota_data`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_quota_data_user_id` (`user_id`),
  ADD KEY `idx_qdt_model_user_name` (`model_name`,`username`),
  ADD KEY `idx_qdt_created_at` (`created_at`);

--
-- 表的索引 `redemptions`
--
ALTER TABLE `redemptions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_redemptions_key` (`key`),
  ADD KEY `idx_redemptions_name` (`name`),
  ADD KEY `idx_redemptions_deleted_at` (`deleted_at`);

--
-- 表的索引 `setups`
--
ALTER TABLE `setups`
  ADD PRIMARY KEY (`id`);

--
-- 表的索引 `tasks`
--
ALTER TABLE `tasks`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_tasks_created_at` (`created_at`),
  ADD KEY `idx_tasks_platform` (`platform`),
  ADD KEY `idx_tasks_user_id` (`user_id`),
  ADD KEY `idx_tasks_channel_id` (`channel_id`),
  ADD KEY `idx_tasks_action` (`action`),
  ADD KEY `idx_tasks_status` (`status`),
  ADD KEY `idx_tasks_start_time` (`start_time`),
  ADD KEY `idx_tasks_finish_time` (`finish_time`),
  ADD KEY `idx_tasks_task_id` (`task_id`),
  ADD KEY `idx_tasks_submit_time` (`submit_time`),
  ADD KEY `idx_tasks_progress` (`progress`);

--
-- 表的索引 `tokens`
--
ALTER TABLE `tokens`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_tokens_key` (`key`),
  ADD KEY `idx_tokens_user_id` (`user_id`),
  ADD KEY `idx_tokens_name` (`name`),
  ADD KEY `idx_tokens_deleted_at` (`deleted_at`);

--
-- 表的索引 `top_ups`
--
ALTER TABLE `top_ups`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_top_ups_user_id` (`user_id`);

--
-- 表的索引 `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `idx_users_access_token` (`access_token`),
  ADD UNIQUE KEY `idx_users_aff_code` (`aff_code`),
  ADD KEY `idx_users_username` (`username`),
  ADD KEY `idx_users_display_name` (`display_name`),
  ADD KEY `idx_users_git_hub_id` (`github_id`),
  ADD KEY `idx_users_oidc_id` (`oidc_id`),
  ADD KEY `idx_users_we_chat_id` (`wechat_id`),
  ADD KEY `idx_users_telegram_id` (`telegram_id`),
  ADD KEY `idx_users_email` (`email`),
  ADD KEY `idx_users_inviter_id` (`inviter_id`),
  ADD KEY `idx_users_deleted_at` (`deleted_at`),
  ADD KEY `idx_users_linux_do_id` (`linux_do_id`);

--
-- 在导出的表使用AUTO_INCREMENT
--

--
-- 使用表AUTO_INCREMENT `channels`
--
ALTER TABLE `channels`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- 使用表AUTO_INCREMENT `logs`
--
ALTER TABLE `logs`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- 使用表AUTO_INCREMENT `midjourneys`
--
ALTER TABLE `midjourneys`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用表AUTO_INCREMENT `quota_data`
--
ALTER TABLE `quota_data`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用表AUTO_INCREMENT `redemptions`
--
ALTER TABLE `redemptions`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用表AUTO_INCREMENT `setups`
--
ALTER TABLE `setups`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- 使用表AUTO_INCREMENT `tasks`
--
ALTER TABLE `tasks`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用表AUTO_INCREMENT `tokens`
--
ALTER TABLE `tokens`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- 使用表AUTO_INCREMENT `top_ups`
--
ALTER TABLE `top_ups`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用表AUTO_INCREMENT `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
