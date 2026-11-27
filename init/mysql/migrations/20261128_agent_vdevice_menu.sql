-- "智能体应用"下新增"虚拟设备"页面：选择项目、应用和设备，生成 alinkiot-vdevice SKILL 的提示词。
-- 依赖 20261127_agent_ops_menu.sql（"智能体应用"目录，path 为 agent）。可重复执行；ID 取 MAX+1，避免与已有菜单冲突。
-- 默认不授予任何角色，由管理员在角色管理里按需勾选。

SET NAMES utf8mb4;

SET @agent_id = (SELECT menu_id FROM sys_menu WHERE parent_id = 0 AND menu_type = 'M' AND path = 'agent' LIMIT 1);

INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
                      menu_type, visible, status, perms, icon, create_by, create_time, remark)
SELECT (SELECT IFNULL(MAX(menu_id), 0) + 1 FROM sys_menu m), '虚拟设备', @agent_id, 4, 'vdevice',
       'system/agentDevice/index', 1, '0', 'C', '0', '0', 'system:agent:vdevice', 'device', 'admin', NOW(), ''
FROM DUAL
WHERE @agent_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM sys_menu x WHERE x.perms = 'system:agent:vdevice');
