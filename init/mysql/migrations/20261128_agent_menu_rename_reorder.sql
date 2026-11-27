-- "智能体运维"目录改名为"智能体应用"，并把它排到"仪表盘"之后；其下的"智能体调试"改名为"远程运维"，"智能体控制"改名为"智能控制"，"应用生成"改名为"智能应用"。
-- 依赖 20261127_agent_ops_menu.sql、20261128_agent_app_menu.sql，须在它们之后执行（它会把页面名设回"智能体调试"）。可重复执行：已经排在仪表盘之后时不再移动其它菜单。
-- 顶级菜单只按 order_num 排序，为避免和"工程项目"同序，把仪表盘之后的顶级菜单依次后移一位。

SET NAMES utf8mb4;

SET @agent_id = (SELECT menu_id FROM sys_menu WHERE parent_id = 0 AND menu_type = 'M' AND path = 'agent' LIMIT 1);
SET @agent_order = (SELECT order_num FROM sys_menu WHERE menu_id = @agent_id);
SET @dash_order = (SELECT order_num FROM sys_menu WHERE parent_id = 0 AND path = 'index' LIMIT 1);

UPDATE sys_menu
SET order_num = order_num + 1, update_by = 'admin', update_time = NOW()
WHERE parent_id = 0 AND menu_id <> @agent_id AND order_num > @dash_order
  AND @agent_id IS NOT NULL AND @dash_order IS NOT NULL AND @agent_order <> @dash_order + 1;

UPDATE sys_menu
SET menu_name = '智能体应用', order_num = @dash_order + 1, update_by = 'admin', update_time = NOW()
WHERE menu_id = @agent_id AND @dash_order IS NOT NULL;

-- 页面及按钮权限改名
UPDATE sys_menu SET menu_name = '远程运维', update_by = 'admin', update_time = NOW() WHERE perms = 'system:remote:query';
UPDATE sys_menu SET menu_name = '远程运维编辑', update_by = 'admin', update_time = NOW() WHERE perms = 'system:remote:edit';
UPDATE sys_menu SET menu_name = '智能控制', update_by = 'admin', update_time = NOW() WHERE perms = 'system:agent:control';
UPDATE sys_menu SET menu_name = '智能应用', update_by = 'admin', update_time = NOW() WHERE perms = 'system:agent:app';
