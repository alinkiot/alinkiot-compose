-- 1. sys_menu 增加 is_top（菜单置顶，顶部导航与搜索快捷入口使用）
SET @has_is_top = (SELECT COUNT(*) FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sys_menu' AND COLUMN_NAME = 'is_top');
SET @ddl = IF(@has_is_top = 0,
              "ALTER TABLE sys_menu ADD COLUMN is_top char(1) DEFAULT '0' COMMENT '是否置顶（0否 1是）' AFTER visible",
              'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. 系统管理下增加"远程调试"页面和编辑按钮。
-- 令牌存在后端 mnesia 内存表里，不需要建表。默认不授予任何角色，由管理员在角色管理里按需勾选
INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
                      menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT (SELECT IFNULL(MAX(menu_id), 0) + 1 FROM sys_menu m), '远程调试', 1, 9, 'remote', 'system/remote/index', 1, '0',
       'C', '0', '0', 'system:remote:query', 'bug', 'admin', NOW(), ''
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM sys_menu x WHERE x.perms = 'system:remote:query');

INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
                      menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT (SELECT IFNULL(MAX(menu_id), 0) + 1 FROM sys_menu m), '远程调试编辑', p.menu_id, 1, '', NULL, 1, '0',
       'F', '0', '0', 'system:remote:edit', '#', 'admin', NOW(), ''
FROM sys_menu p
WHERE p.perms = 'system:remote:query'
  AND NOT EXISTS (SELECT 1 FROM sys_menu x WHERE x.perms = 'system:remote:edit');

-- 3. 清理早先"应用关联远程工具"方案的遗留对象（未发布，只在开发环境存在过）
DROP TABLE IF EXISTS sys_app_remote;
DELETE FROM sys_menu WHERE perms = 'system:app:remote';
