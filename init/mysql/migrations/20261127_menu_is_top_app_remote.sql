-- 1. sys_menu 增加 is_top（菜单置顶，顶部导航与搜索快捷入口使用）
SET @has_is_top = (SELECT COUNT(*) FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sys_menu' AND COLUMN_NAME = 'is_top');
SET @ddl = IF(@has_is_top = 0,
              "ALTER TABLE sys_menu ADD COLUMN is_top char(1) DEFAULT '0' COMMENT '是否置顶（0否 1是）' AFTER visible",
              'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. 应用远程工具凭证。存在记录即表示该应用开启了远程工具，库中只保存 token 的 sha256
CREATE TABLE IF NOT EXISTS sys_app_remote (
  app_id int(11) NOT NULL COMMENT '应用ID',
  token_hash char(64) NOT NULL COMMENT 'token 的 sha256',
  create_by varchar(64) DEFAULT '' COMMENT '开启人',
  create_time datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (app_id),
  UNIQUE KEY uk_token_hash (token_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 3. 应用管理下增加"远程工具"按钮权限。默认不授予任何角色，由管理员在角色管理里按需勾选
INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
                      menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT (SELECT IFNULL(MAX(menu_id), 0) + 1 FROM sys_menu m), '远程工具', p.menu_id, 5, '', NULL, 1, '0',
       'F', '0', '0', 'system:app:remote', '#', 'admin', NOW(), ''
FROM sys_menu p
WHERE p.perms = 'system:app:list'
  AND NOT EXISTS (SELECT 1 FROM sys_menu x WHERE x.perms = 'system:app:remote');
