-- 新增"智能体运维"目录：把"远程调试"移进来改名为"智能体调试"，并新增"智能体控制"页面。
-- 依赖 20261127_menu_is_top_remote_debug.sql（远程调试菜单）。可重复执行；ID 取 MAX+1，避免与已有菜单冲突。
-- 默认不授予任何角色，由管理员在角色管理里按需勾选。

SET NAMES utf8mb4;

-- 1. 顶级目录"智能体运维"
INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
                      menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT (SELECT IFNULL(MAX(menu_id), 0) + 1 FROM sys_menu m), '智能体运维', 0, 9, 'agent', NULL, 1, '0',
       'M', '0', '0', NULL, 'code', 'admin', NOW(), ''
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM sys_menu x WHERE x.parent_id = 0 AND x.menu_type = 'M' AND x.path = 'agent');

SET @agent_id = (SELECT menu_id FROM sys_menu WHERE parent_id = 0 AND menu_type = 'M' AND path = 'agent' LIMIT 1);

-- 2. "远程调试"移到"智能体运维"下，改名"智能体调试"；按钮权限随父菜单一起移动，不用改
UPDATE sys_menu
SET parent_id = @agent_id, menu_name = '智能体调试', order_num = 1, update_by = 'admin', update_time = NOW()
WHERE perms = 'system:remote:query' AND @agent_id IS NOT NULL;

UPDATE sys_menu SET menu_name = '智能体调试编辑' WHERE perms = 'system:remote:edit';

-- 3. 新增"智能体控制"页面：选择应用生成 uzyiot-api SKILL 的提示词
INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
                      menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT (SELECT IFNULL(MAX(menu_id), 0) + 1 FROM sys_menu m), '智能体控制', @agent_id, 2, 'control',
       'system/agentControl/index', 1, '0', 'C', '0', '0', 'system:agent:control', 'server', 'admin', NOW(), ''
FROM DUAL
WHERE @agent_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM sys_menu x WHERE x.perms = 'system:agent:control');
