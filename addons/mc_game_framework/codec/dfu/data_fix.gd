## DataFix — DFU 风格数据修复/迁移步骤
##
## 对齐 Mojang DFU DataFix 设计：
## - 每个 DataFix 负责将数据从一个版本迁移到下一个版本
## - 支持结构迁移（字段改名、拆分、嵌套重组）和语义迁移（枚举映射、默认值变化）
## - 通过 TypeRewriteRule 指定迁移逻辑
extends RefCounted
class_name DataFix

## 迁移前版本
var from_version: int
## 迁移后版本
var to_version: int
## 描述信息
var description: String

## 迁移规则列表
var _rules: Array = []  ## Array[TypeRewriteRule]

func _init(p_from: int, p_to: int, p_description: String = "") -> void:
	from_version = p_from
	to_version = p_to
	description = p_description

## 添加迁移规则
func add_rule(rule: TypeRewriteRule) -> DataFix:
	_rules.append(rule)
	return self

## 执行迁移：将数据从 from_version 升级到 to_version
## data: 原始数据（通常是 Dictionary）
## ops: DynamicOps 实例
## type_name: 正在迁移的类型名称（可选，用于 dispatch 规则）
func apply(data: Variant, ops: DynamicOps, type_name: String = "") -> DataResult:
	var current := data
	for rule: TypeRewriteRule in _rules:
		if not type_name.is_empty() and not rule.applies_to(type_name):
			continue
		var result := rule.apply(current, ops)
		if result.is_error():
			return result
		current = result.get_value()
	return DataResult.success(current)

func _to_string() -> String:
	return "DataFix(v%d -> v%d: %s, rules=%d)" % [from_version, to_version, description, _rules.size()]
