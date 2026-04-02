## DataFixerUpper — DFU 风格数据迁移管理器
##
## 对齐 Mojang DFU DataFixerUpper 设计：
## - 管理 Schema 版本图和 DataFix 迁移链
## - 支持从任意旧版本向前升级到最新版本
## - 第一阶段只支持单向前进升级，不支持任意双向转换
extends RefCounted
class_name DataFixerUpper

## Schema 版本列表（按版本号排序）
var _schemas: Dictionary = {}  ## int -> Schema
## 迁移步骤列表（按 from_version 排序）
var _fixes: Array = []  ## Array[DataFix]
## 最新版本号
var _latest_version: int = 0

## 注册 Schema
func add_schema(schema: Schema) -> DataFixerUpper:
	_schemas[schema.version] = schema
	if schema.version > _latest_version:
		_latest_version = schema.version
	return self

## 注册迁移步骤
func add_fix(fix: DataFix) -> DataFixerUpper:
	_fixes.append(fix)
	# 保持按 from_version 排序
	_fixes.sort_custom(func(a: DataFix, b: DataFix): return a.from_version < b.from_version)
	return self

## 获取最新版本号
func get_latest_version() -> int:
	return _latest_version

## 获取指定版本的 Schema
func get_schema(version: int) -> Schema:
	return _schemas.get(version)

## 执行数据迁移：将数据从 data_version 升级到 target_version
## data: 原始数据
## data_version: 数据当前版本
## target_version: 目标版本（默认为最新版本，-1 表示最新）
## ops: DynamicOps 实例
## type_name: 数据类型名称（用于 dispatch 规则筛选）
func update(data: Variant, data_version: int, ops: DynamicOps, type_name: String = "", target_version: int = -1) -> DataResult:
	if target_version < 0:
		target_version = _latest_version

	if data_version >= target_version:
		return DataResult.success(data)

	var current := data
	var current_version := data_version
	var all_diagnostics: Array = []

	# 按顺序执行迁移链
	for fix: DataFix in _fixes:
		if fix.from_version < current_version:
			continue
		if fix.from_version >= target_version:
			break
		if fix.from_version != current_version:
			# 跳过不连续的版本
			continue

		var result := fix.apply(current, ops, type_name)
		all_diagnostics.append_array(result.get_diagnostics())

		if result.is_error():
			var err := DataResult.error(
				"Migration failed at v%d -> v%d (%s): %s" % [fix.from_version, fix.to_version, fix.description, result.get_error()])
			err._diagnostics = all_diagnostics
			return err

		current = result.get_value()
		current_version = fix.to_version

	if current_version < target_version:
		var r := DataResult.partial(current,
			"Migration incomplete: reached v%d but target is v%d (missing fix chain)" % [current_version, target_version])
		r._diagnostics = all_diagnostics
		return r

	var r := DataResult.success(current)
	r._diagnostics = all_diagnostics
	return r

## 便捷方法：读取、迁移、解码一步完成
## raw_data: 原始载体数据
## data_version: 数据当前版本号
## codec: 最新版本的 Codec
## ops: DynamicOps 实例
## type_name: 类型名称
func update_and_decode(raw_data: Variant, data_version: int, codec: Codec, ops: DynamicOps, type_name: String = "") -> DataResult:
	var migrated := update(raw_data, data_version, ops, type_name)
	if migrated.is_error():
		return migrated

	var decode_result := codec.decode(migrated.get_value(), ops)
	# 合并诊断
	var merged_diagnostics := migrated.get_diagnostics().duplicate()
	merged_diagnostics.append_array(decode_result.get_diagnostics())
	decode_result._diagnostics = merged_diagnostics
	return decode_result

func _to_string() -> String:
	return "DataFixerUpper(latest=v%d, schemas=%d, fixes=%d)" % [_latest_version, _schemas.size(), _fixes.size()]
