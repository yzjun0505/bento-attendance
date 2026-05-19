<template>
  <div class="page-container">
    <div class="header-actions">
      <div class="header-titles">
        <h1 class="main-title">水印模版库</h1>
        <p class="sub-title">管理和预设手机端的打卡水印样式</p>
      </div>
      
      <div class="header-controls">
        <el-radio-group v-model="filterType" class="filter-group">
          <el-radio-button label="全部">全部</el-radio-button>
          <el-radio-button label="日常打卡">日常打卡</el-radio-button>
          <el-radio-button label="工程施工">工程施工</el-radio-button>
          <el-radio-button label="外勤巡检">外勤巡检</el-radio-button>
        </el-radio-group>
        <el-button type="primary" @click="openEditor('new')" class="new-btn">+ 新建水印模版</el-button>
      </div>
    </div>

    <div class="gallery-grid">
      <div class="watermark-card" v-for="item in filteredTemplates" :key="item.id">
        <div class="card-thumbnail">
          <div class="card-preview-canvas">
            <div class="card-preview-frame">
              <div class="card-preview-watermark" :class="getWatermarkPresetClass(item.schema, true)" :style="getWatermarkRenderStyle(item.schema, true)">
                <div class="card-preview-title" :style="getTemplateSlotStyle(item, 'title')">
                  {{ getTemplateSlotText(item, 'title', getWatermarkTitle(item)) }}
                </div>
                <div class="card-preview-subtitle" :style="getTemplateSlotStyle(item, 'subtitle')">
                  {{ getTemplateSlotText(item, 'subtitle', '2026-04-23 12:00:00') }}
                </div>
                <div class="card-preview-fields">
                  <div class="card-preview-field" v-for="field in item.schema?.customSlots || []" :key="field.id">
                    <span class="card-preview-field-text" :style="getTemplateSlotStyle(item, field.id)">
                      {{ field.label }}：{{ getTemplateSlotText(item, field.id, getMockValue(field.type), field.type) }}
                    </span>
                  </div>
                </div>
                <div class="card-preview-bottom" :style="getTemplateSlotStyle(item, 'bottomInfo')">
                  {{ getTemplateSlotText(item, 'bottomInfo', 'xx省xx市xx区') }}
                </div>
              </div>
            </div>
          </div>
          <div class="card-hover-actions">
            <el-button plain size="small" @click="openEditor('edit', item)">编辑</el-button>
            <el-button type="danger" plain size="small" @click="deleteTemplate(item.id)">删除</el-button>
          </div>
        </div>
        <div class="card-info">
          <div class="card-name">{{ item.name }}</div>
          <el-tag size="small" :type="isTemplateActive(item.status) ? 'success' : 'info'">{{ isTemplateActive(item.status) ? '启用中' : '未启用' }}</el-tag>
        </div>
        <div v-if="item.title" class="card-title-preview">水印标题: {{ item.title }}</div>
      </div>
    </div>

    <el-drawer
      v-model="editorVisible"
      direction="btt"
      size="100%"
      :with-header="false"
      class="editor-drawer"
    >
      <div class="editor-layout">
        <div class="editor-header">
          <div class="editor-title">{{ editorMode === 'new' ? '新建水印模版' : '编辑水印模版' }}</div>
          <div class="editor-actions">
            <el-button @click="editorVisible = false">取消</el-button>
            <el-button type="primary" @click="saveTemplate">保存</el-button>
          </div>
        </div>
        
        <div class="editor-body">
          <div class="editor-left">
            <h3>模板信息</h3>
            <div class="template-info-form">
              <el-form label-position="top" class="slot-detail-form">
                <el-form-item label="模板名称（管理端展示）">
                  <el-input v-model="currentConfig.name" placeholder="请输入模板名称" />
                </el-form-item>
                <el-form-item label="水印主标题（手机端展示）">
                  <el-input v-model="currentConfig.title" placeholder="请输入水印主标题，如：施工进度" />
                </el-form-item>
              </el-form>
            </div>
            <el-divider />
            <h3>背景场景</h3>
            <div class="scene-list">
              <el-radio-group v-model="globalSettings.scene" class="scene-radio-group">
                <el-radio label="solid">纯色 (Solid)</el-radio>
                <el-radio label="day_construction">白天施工</el-radio>
                <el-radio label="night_street">夜晚街道</el-radio>
                <el-radio label="blueprint">图纸</el-radio>
              </el-radio-group>
            </div>
            <el-divider />
            <h3>基础骨架</h3>
            <div class="skeleton-list">
              <div
                v-for="preset in skeletonPresets"
                :key="preset.id"
                class="skeleton-item"
                :class="{ active: currentSkeletonPreset.id === preset.id }"
                @click="setSkeletonPreset(preset.id)"
              >
                <div class="skeleton-item-title">{{ preset.label }}</div>
                <div class="skeleton-item-desc">{{ preset.description }}</div>
              </div>
            </div>
            <el-divider />
            <h3>全局设置</h3>
            <div class="setting-item">
              <span>背景颜色</span>
              <el-color-picker v-model="globalSettings.bgColor" show-alpha />
            </div>
          </div>

          <div class="editor-middle editor-canvas">
            <div class="iphone-mockup">
              <div class="iphone-screen" :class="'scene-' + globalSettings.scene">
                <div class="iphone-camera-overlay" :style="{ backgroundColor: globalSettings.scene === 'solid' ? globalSettings.bgColor : 'transparent' }"></div>
                <div class="preview-content">
                  <div class="preview-watermark" :class="getWatermarkPresetClass(currentConfig.schema)" :style="getWatermarkRenderStyle(currentConfig.schema)">
                    <div class="preview-title" :style="getSlotStyle('title')">{{ getSlotText('title', currentConfig.title || currentConfig.name || '水印名称') }}</div>
                    <div class="preview-subtitle" :style="getSlotStyle('subtitle')">{{ getSlotText('subtitle', '2026-04-23 12:00:00') }}</div>
                    <div class="preview-fields">
                      <div class="preview-field" v-for="field in currentConfig.schema.customSlots" :key="field.id">
                        <span class="preview-field-text" :style="getSlotStyle(field.id)">{{ field.label }}：{{ getSlotText(field.id, getMockValue(field.type), field.type) }}</span>
                      </div>
                    </div>
                    <div class="preview-bottom" :style="getSlotStyle('bottomInfo')">{{ getSlotText('bottomInfo', 'xx省xx市xx区') }}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="editor-right" :class="{ 'has-detail': !!activeSlotId }">
            <div class="slot-list-panel">
              <h3>字段配置 (插槽设置)</h3>

              <div class="slot-section-title">内置插槽</div>
              <div class="slot-list">
                <div class="slot-card" v-for="slot in builtInSlots" :key="slot.id">
                  <div class="slot-header">
                    <div class="slot-header-left">
                      <span class="slot-title">{{ slot.label }}</span>
                      <span class="slot-summary">{{ getSlotSummary(slot.id) }}</span>
                    </div>
                    <el-button link class="slot-action-btn" @click="openSlotDetail(slot.id)">
                      <el-icon><Setting /></el-icon>
                    </el-button>
                  </div>
                </div>
              </div>

              <div class="slot-section-title">自定义插槽</div>
              <draggable
                v-model="customSlotsList"
                item-key="id"
                class="slot-list"
                handle=".drag-handle"
                :animation="200"
              >
                <template #item="{ element }">
                  <div class="slot-card">
                    <div class="slot-header">
                      <div class="slot-header-left">
                        <el-icon class="drag-handle"><Menu /></el-icon>
                        <span class="slot-title">{{ element.label }}</span>
                        <span class="slot-summary">{{ getSlotSummary(element.id, element.type) }}</span>
                      </div>
                      <div class="slot-header-actions">
                        <el-button link class="slot-action-btn" @click="openSlotDetail(element.id)">
                          <el-icon><Setting /></el-icon>
                        </el-button>
                        <el-button type="danger" link @click="deleteSlot(element.id)">删除</el-button>
                      </div>
                    </div>
                    <div class="slot-body">
                      <span class="slot-type">类型: {{ element.type }}</span>
                    </div>
                  </div>
                </template>
              </draggable>

              <el-button class="add-field-btn" type="primary" plain style="width: 100%; margin-top: 16px;" @click="addSlot">+ 新增自定义插槽</el-button>
            </div>

            <div v-if="activeSlotId" ref="slotDetailPanelRef" class="slot-detail-panel">
              <div class="slot-detail-header">
                <div class="slot-detail-title">{{ activeSlotMeta?.label || activeSlotId }}</div>
                <el-button link class="slot-action-btn" @click="closeSlotDetail">
                  <el-icon><Close /></el-icon>
                </el-button>
              </div>

              <el-form label-position="top" class="slot-detail-form">
                <el-form-item label="数据绑定">
                  <el-select
                    :model-value="activeSlotConfig.binding"
                    @update:model-value="updateSlotConfig('binding', $event)"
                    placeholder="选择数据源"
                    clearable
                    filterable
                    :teleported="true"
                    :append-to="slotDetailPanelRef || 'body'"
                    :loading="bindingOptionsLoading"
                    :no-data-text="bindingOptionsLoading ? '加载中...' : '暂无可绑定字段'"
                    :fallback-placements="['bottom-start', 'top-start', 'right', 'left']"
                    style="width: 100%;"
                  >
                    <el-option
                      v-for="opt in filteredBindingOptions"
                      :key="opt.value"
                      :label="opt.label"
                      :value="opt.value"
                    />
                  </el-select>
                </el-form-item>

                <el-form-item label="自定义文本">
                  <el-input
                    :model-value="activeSlotConfig.customText"
                    @update:model-value="updateSlotConfig('customText', $event)"
                    type="textarea"
                    :rows="3"
                    placeholder="优先生效，留空则使用绑定值/默认值"
                  />
                </el-form-item>

                <el-form-item label="手机端权限">
                  <el-radio-group
                    :model-value="activeSlotConfig.permission"
                    @update:model-value="updateSlotConfig('permission', $event)"
                  >
                    <el-radio-button label="open">开放</el-radio-button>
                    <el-radio-button label="locked">锁定</el-radio-button>
                  </el-radio-group>
                </el-form-item>

                <el-divider />

                <el-form-item label="字号">
                  <el-input-number
                    :model-value="activeSlotConfig.style.fontSize"
                    @update:model-value="updateSlotStyle('fontSize', $event)"
                    :min="10"
                    :max="48"
                    :step="1"
                    controls-position="right"
                    style="width: 100%;"
                  />
                </el-form-item>

                <el-form-item label="文字颜色">
                  <el-color-picker
                    :model-value="activeSlotConfig.style.color"
                    @update:model-value="updateSlotStyle('color', $event)"
                    show-alpha
                  />
                </el-form-item>

                <el-form-item label="背景颜色">
                  <el-color-picker
                    :model-value="activeSlotConfig.style.bgColor"
                    @update:model-value="updateSlotStyle('bgColor', $event)"
                  />
                </el-form-item>

                <el-form-item label="背景透明度">
                  <el-slider
                    :model-value="activeSlotConfig.style.opacity"
                    @update:model-value="updateSlotStyle('opacity', $event)"
                    :min="0"
                    :max="1"
                    :step="0.05"
                    show-input
                  />
                </el-form-item>
              </el-form>
            </div>
          </div>
        </div>
      </div>
    </el-drawer>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import request from '@/api/request'
import { ElMessage, ElMessageBox } from 'element-plus'
import draggable from 'vuedraggable'
import { Menu, Setting, Close } from '@element-plus/icons-vue'

const filterType = ref('全部')
const templates = ref([])
const editorVisible = ref(false)
const editorMode = ref('new')
const activeSlotId = ref(null)
const slotDetailPanelRef = ref(null)

const globalSettings = ref({
  bgColor: 'rgba(0, 0, 0, 0.4)',
  scene: 'solid'
})

const defaultSkeletonPresetId = 'default'
const skeletonPresets = [
  {
    id: 'default',
    label: '默认样式',
    description: '经典半透明底板，适合通用打卡'
  },
  {
    id: 'glass',
    label: '毛玻璃底',
    description: '轻透磨砂卡片，适合夜景和城市背景'
  },
  {
    id: 'clean',
    label: '无背景板',
    description: '只保留文字，不额外加底板'
  },
  {
    id: 'compact',
    label: '紧凑标签',
    description: '更紧凑的底板和信息间距'
  }
]

const builtInSlots = [
  { id: 'title', label: '大标题', defaultStyle: { fontSize: 18 } },
  { id: 'subtitle', label: '副标题', defaultStyle: { fontSize: 13 } },
  { id: 'bottomInfo', label: '底部信息', defaultStyle: { fontSize: 12 } }
]

const createDefaultBindingOptions = () => ([
  { value: 'userName', label: '打卡人', slotTypes: ['文本'], example: '张三' },
  { value: 'projectName', label: '项目名称', slotTypes: ['文本'], example: '示例项目' },
  { value: 'position', label: '岗位/工种', slotTypes: ['文本'], example: '施工员' },
  { value: 'checkinTime', label: '完整时间', slotTypes: ['时间', '文本'], example: '2026-04-23 12:00:00' },
  { value: 'timeDate', label: '日期', slotTypes: ['时间', '文本'], example: '2026-04-23 星期四' },
  { value: 'timeOnly', label: '时分秒', slotTypes: ['时间', '文本'], example: '12:00:00' },
  { value: 'location', label: '详细地址', slotTypes: ['地理位置', '文本'], example: 'xx省xx市xx区' },
  { value: 'gps', label: '经纬度', slotTypes: ['地理位置', '文本'], example: '116.397, 39.908' },
  { value: 'gpsLat', label: '纬度', slotTypes: ['地理位置', '文本'], example: '纬度: 39.908000' },
  { value: 'gpsLng', label: '经度', slotTypes: ['地理位置', '文本'], example: '经度: 116.397000' },
  { value: 'altitude', label: '海拔', slotTypes: ['地理位置', '文本'], example: '120m' },
  { value: 'weather', label: '天气', slotTypes: ['文本'], example: '晴' },
  { value: 'temperature', label: '温度', slotTypes: ['文本'], example: '25℃' },
  { value: 'humidity', label: '湿度', slotTypes: ['文本'], example: '60%' },
  { value: 'device', label: '设备型号', slotTypes: ['文本'], example: 'iPhone 15 Pro' },
  { value: 'deviceNo', label: '设备编号', slotTypes: ['文本'], example: 'DEV-001' },
  { value: 'remark', label: '备注', slotTypes: ['文本'], example: '现场正常' },
  { value: 'antiFakeCode', label: '防伪码', slotTypes: ['文本'], example: 'WM20260423001' }
])

const bindingOptions = ref(createDefaultBindingOptions())
const bindingOptionsLoading = ref(false)

const currentConfig = ref({
  name: '',
  title: '',
  status: 1,
  schema: {
    customSlots: [],
    slots: {}
  }
})

const createDefaultCustomSlots = () => ([
  { id: '1', label: '打卡人', type: '文本' },
  { id: '2', label: '打卡时间', type: '时间' },
  { id: '3', label: '位置', type: '地理位置' }
])

const createDefaultLayout = () => ({
  version: 2,
  designCanvas: { width: 1080, height: 1920 },
  referenceWidth: 390,
  surface: {
    x: 0.08,
    y: 0.68,
    width: 0.72,
    padding: 16,
    lineHeight: 1.6,
    radius: 12
  }
})

const createDefaultSchema = () => ({
  version: 2,
  designCanvas: { width: 1080, height: 1920 },
  layout: createDefaultLayout(),
  skeletonPreset: defaultSkeletonPresetId,
  customSlots: createDefaultCustomSlots(),
  slots: {}
})

const cloneDeep = (value) => {
  try {
    return JSON.parse(JSON.stringify(value))
  } catch {
    return value
  }
}

const isEditorSchema = (schema) => {
  if (!schema || typeof schema !== 'object') return false
  return Array.isArray(schema.customSlots) || !!(schema.slots && typeof schema.slots === 'object')
}

const normalizeTemplateStatus = (status) => {
  if (status === 'active') return 1
  if (status === 'inactive') return 0
  return Number(status ?? 1) === 0 ? 0 : 1
}

const bindingAliasMap = {
  name: 'userName',
  user: 'userName',
  time: 'checkinTime',
  project: 'projectName',
  address: 'location'
}

const normalizeBindingValue = (binding) => {
  if (!binding) return ''
  return bindingAliasMap[binding] || binding
}

const toNumberInRange = (value, fallback, min, max) => {
  const num = Number(value)
  if (!Number.isFinite(num)) return fallback
  return Math.max(min, Math.min(max, num))
}

const normalizeLayout = (layout = {}) => {
  const defaults = createDefaultLayout()
  const source = layout && typeof layout === 'object' ? layout : {}
  const surface = source.surface && typeof source.surface === 'object' ? source.surface : {}

  return {
    ...defaults,
    ...source,
    version: 2,
    designCanvas: {
      width: toNumberInRange(source.designCanvas?.width, 1080, 1, 4096),
      height: toNumberInRange(source.designCanvas?.height, 1920, 1, 4096)
    },
    referenceWidth: toNumberInRange(source.referenceWidth, 390, 240, 1024),
    surface: {
      ...defaults.surface,
      ...surface,
      x: toNumberInRange(surface.x, defaults.surface.x, 0, 1),
      y: toNumberInRange(surface.y, defaults.surface.y, 0, 1),
      width: toNumberInRange(surface.width, defaults.surface.width, 0.2, 1),
      padding: toNumberInRange(surface.padding, defaults.surface.padding, 0, 80),
      lineHeight: toNumberInRange(surface.lineHeight, defaults.surface.lineHeight, 1, 2.4),
      radius: toNumberInRange(surface.radius, defaults.surface.radius, 0, 48)
    }
  }
}

const normalizeLoadedSchema = (schemaSource) => {
  const schema = isEditorSchema(schemaSource) ? cloneDeep(schemaSource) : createDefaultSchema()
  schema.version = 2
  schema.designCanvas = schema.designCanvas || { width: 1080, height: 1920 }
  schema.layout = normalizeLayout(schema.layout)
  const presetExists = skeletonPresets.some(preset => preset.id === schema.skeletonPreset)
  schema.skeletonPreset = presetExists ? schema.skeletonPreset : defaultSkeletonPresetId
  if (!Array.isArray(schema.customSlots)) schema.customSlots = []
  if (!schema.slots || typeof schema.slots !== 'object') schema.slots = {}

  Object.values(schema.slots).forEach((slotConfig) => {
    if (slotConfig && typeof slotConfig === 'object') {
      slotConfig.binding = normalizeBindingValue(slotConfig.binding)
    }
  })

  return schema
}

const normalizeTemplate = (item = {}) => {
  const schemaSource = item.schema ?? item.schema_json
  return {
    ...item,
    status: normalizeTemplateStatus(item.status),
    schema: normalizeLoadedSchema(schemaSource)
  }
}

// 获取水印标题（优先使用title，否则使用name）
const getWatermarkTitle = (item) => {
  return item?.title || item?.name || '水印名称'
}

const customSlotsList = computed({
  get: () => currentConfig.value.schema.customSlots || [],
  set: (val) => {
    currentConfig.value.schema.customSlots = val
    // 当拖拽改变顺序时，不触发额外的引用改变，直接修改源数组
  }
})

const filteredTemplates = computed(() => {
  if (filterType.value === '全部') {
    return templates.value
  }
  return templates.value.filter(t => t.type === filterType.value)
})

const currentSkeletonPreset = computed(() => {
  const presetId = currentConfig.value?.schema?.skeletonPreset || defaultSkeletonPresetId
  return skeletonPresets.find(preset => preset.id === presetId) || skeletonPresets[0]
})

const filteredBindingOptions = computed(() => {
  const slotType = activeSlotMeta.value?.type
  const options = bindingOptions.value || []
  if (!slotType) return options
  const matched = options.filter(opt => !Array.isArray(opt.slotTypes) || opt.slotTypes.includes(slotType))
  return matched.length > 0 ? matched : options
})

const isTemplateActive = (status) => normalizeTemplateStatus(status) === 1

const fetchTemplates = async () => {
  try {
    const res = await request.get('/watermarks/all')
    templates.value = (res.data || []).map(normalizeTemplate)
  } catch (err) {
    console.error('Failed to fetch templates:', err)
    templates.value = [
      { id: 1, name: '日常考勤水印', type: '日常打卡', status: 'active' },
      { id: 2, name: '施工现场打卡', type: '工程施工', status: 'active' },
      { id: 3, name: '设备巡检记录', type: '外勤巡检', status: 'inactive' },
      { id: 4, name: '临时外勤', type: '外勤巡检', status: 'active' },
    ].map(normalizeTemplate)
  }
}

const fetchBindingOptions = async () => {
  bindingOptionsLoading.value = true
  try {
    const res = await request.get('/watermarks/binding-options')
    const options = Array.isArray(res.data) ? res.data : []
    if (options.length > 0) {
      bindingOptions.value = options
    } else {
      bindingOptions.value = createDefaultBindingOptions()
    }
  } catch (err) {
    console.error('Failed to fetch binding options:', err)
    bindingOptions.value = createDefaultBindingOptions()
  } finally {
    bindingOptionsLoading.value = false
  }
}

onMounted(() => {
  fetchTemplates()
  fetchBindingOptions()
})

const createDefaultSlotConfig = (overrides = {}) => {
  const base = {
    binding: '',
    customText: '',
    permission: 'open',
    style: {
      fontSize: undefined,
      color: '',
      bgColor: '',
      opacity: 0.5
    }
  }
  return {
    ...base,
    ...overrides,
    style: {
      ...base.style,
      ...(overrides.style || {})
    }
  }
}

const normalizeSchema = () => {
  const schema = (currentConfig.value.schema ||= {})
  schema.version = 2
  schema.designCanvas = schema.designCanvas || { width: 1080, height: 1920 }
  schema.layout = normalizeLayout(schema.layout)
  const presetExists = skeletonPresets.some(preset => preset.id === schema.skeletonPreset)
  schema.skeletonPreset = presetExists ? schema.skeletonPreset : defaultSkeletonPresetId
  if (!Array.isArray(schema.customSlots)) schema.customSlots = []
  if (!schema.slots || typeof schema.slots !== 'object') schema.slots = {}

  for (const slot of builtInSlots) {
    schema.slots[slot.id] = createDefaultSlotConfig({
      ...(schema.slots[slot.id] || {}),
      style: {
        ...(slot.defaultStyle || {}),
        ...((schema.slots[slot.id] && schema.slots[slot.id].style) || {})
      }
    })
  }

  for (const custom of schema.customSlots) {
    schema.slots[custom.id] = createDefaultSlotConfig({
      ...(schema.slots[custom.id] || {}),
      style: {
        fontSize: 13,
        ...((schema.slots[custom.id] && schema.slots[custom.id].style) || {})
      }
    })
  }

  if (activeSlotId.value && !schema.slots[activeSlotId.value]) {
    activeSlotId.value = null
  }
}

const getSlotConfigFromSchema = (schema, slotId) => {
  if (!slotId || !schema || typeof schema !== 'object') return null
  return schema?.slots?.[slotId] || null
}

const getSlotConfig = (slotId) => {
  return getSlotConfigFromSchema(currentConfig.value?.schema, slotId)
}

const ensureEditableSlotConfig = (slotId) => {
  if (!slotId) return null
  normalizeSchema()
  if (!currentConfig.value.schema.slots[slotId]) {
    currentConfig.value.schema.slots[slotId] = createDefaultSlotConfig()
  }
  return currentConfig.value.schema.slots[slotId]
}

const activeSlotConfig = computed({
  get: () => ensureEditableSlotConfig(activeSlotId.value),
  set: (val) => {
    if (activeSlotId.value) {
      currentConfig.value.schema.slots[activeSlotId.value] = val
    }
  }
})

const activeSlotMeta = computed(() => {
  const id = activeSlotId.value
  if (!id) return null
  const builtIn = builtInSlots.find(s => s.id === id)
  if (builtIn) return builtIn
  const custom = currentConfig.value.schema.customSlots.find(s => s.id === id)
  if (custom) return { id: custom.id, label: custom.label, type: custom.type }
  return null
})

const openSlotDetail = (slotId) => {
  activeSlotId.value = slotId
  ensureEditableSlotConfig(slotId)
}

const setSkeletonPreset = (presetId) => {
  if (!currentConfig.value.schema) {
    currentConfig.value.schema = createDefaultSchema()
  }
  currentConfig.value.schema.skeletonPreset = presetId
}

const closeSlotDetail = () => {
  activeSlotId.value = null
}

const updateSlotConfig = (key, value) => {
  const config = ensureEditableSlotConfig(activeSlotId.value)
  if (config) {
    config[key] = value
  }
}

const updateSlotStyle = (key, value) => {
  const config = ensureEditableSlotConfig(activeSlotId.value)
  if (config && config.style) {
    config.style[key] = value
  }
}

const getBindingLabel = (binding) => {
  if (!binding) return ''
  const normalizedBinding = normalizeBindingValue(binding)
  return bindingOptions.value.find(o => o.value === normalizedBinding)?.label || normalizedBinding
}

const getSlotSummary = (slotId, fallbackType = '') => {
  const config = getSlotConfig(slotId)
  if (!config) return fallbackType || '默认'
  if (config.customText) return `文本：${config.customText}`
  if (config.binding) return `绑定：${getBindingLabel(config.binding)}`
  return fallbackType || '默认'
}

const openEditor = (mode, item = null) => {
  editorMode.value = mode
  if (mode === 'edit' && item) {
    currentConfig.value = normalizeTemplate(item)
  } else {
    currentConfig.value = {
      name: '新建水印',
      title: '',
      status: 1,
      schema: createDefaultSchema()
    }
  }
  activeSlotId.value = null
  normalizeSchema()
  editorVisible.value = true
}

const saveTemplate = async () => {
  try {
    if (editorMode.value === 'new') {
      await request.post('/watermarks', currentConfig.value)
    } else {
      await request.put(`/watermarks/${currentConfig.value.id}`, currentConfig.value)
    }
    ElMessage.success('保存成功')
    editorVisible.value = false
    fetchTemplates()
  } catch (err) {
    console.error(err)
    ElMessage.error('保存失败')
  }
}

const deleteTemplate = async (id) => {
  try {
    await ElMessageBox.confirm('删除后将无法恢复，确定删除这个水印模板吗？', '删除确认', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await request.delete(`/watermarks/${id}`)
    ElMessage.success('删除成功')
    await fetchTemplates()
  } catch (err) {
    if (err === 'cancel' || err === 'close') return
    console.error('删除模板失败:', err)
    ElMessage.error('删除失败')
  }
}

const addSlot = () => {
  ElMessageBox.prompt('请输入插槽名称', '新增自定义插槽', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
  }).then(({ value }) => {
    if (value) {
      const id = Date.now().toString()
      // 注意：这里需要重新赋值整个数组来触发 vuedraggable 代理的 setter，
      // 因为直接 push 数组方法在某些组合式 API 代理下可能会丢失更新
      currentConfig.value.schema.customSlots = [
        ...(currentConfig.value.schema.customSlots || []),
        { id, label: value, type: '文本' }
      ]
      normalizeSchema()
      currentConfig.value.schema.slots[id] = createDefaultSlotConfig({
        style: { fontSize: 13 }
      })
      openSlotDetail(id)
    }
  }).catch(() => {})
}

const deleteSlot = (id) => {
  currentConfig.value.schema.customSlots = currentConfig.value.schema.customSlots.filter(s => s.id !== id)
  if (currentConfig.value.schema.slots) {
    delete currentConfig.value.schema.slots[id]
  }
  if (activeSlotId.value === id) {
    activeSlotId.value = null
  }
}

const getMockValue = (type) => {
  switch(type) {
    case '文本': return '张三'
    case '时间': return '2026-04-23 12:00'
    case '地理位置': return 'xx省xx市xx区'
    default: return '内容'
  }
}

const getMockValueByBinding = (binding, typeHint = '') => {
  switch (normalizeBindingValue(binding)) {
    case 'userName': return '张三'
    case 'checkinTime': return '2026-04-23 12:00:00'
    case 'timeDate': return '2026-04-23 星期四'
    case 'timeOnly': return '12:00:00'
    case 'location': return 'xx省xx市xx区'
    case 'projectName': return '示例项目'
    case 'position': return '施工员'
    case 'weather': return '晴 25℃'
    case 'gps': return '116.397, 39.908'
    case 'gpsLat': return '纬度: 39.908000'
    case 'gpsLng': return '经度: 116.397000'
    case 'altitude': return '120m'
    case 'device': return 'iPhone 15 Pro'
    case 'deviceNo': return 'DEV-001'
    case 'temperature': return '25℃'
    case 'humidity': return '60%'
    case 'remark': return '现场正常'
    case 'antiFakeCode': return 'WM20260423001'
    default: return getMockValue(typeHint)
  }
}

const getSlotText = (slotId, fallbackText, typeHint = '') => {
  const config = getSlotConfig(slotId)
  if (!config) return fallbackText
  const text = (config.customText || '').trim()
  if (text) return text
  if (config.binding) return getMockValueByBinding(config.binding, typeHint)
  return fallbackText
}

const getTemplateSlotText = (template, slotId, fallbackText, typeHint = '') => {
  const config = getSlotConfigFromSchema(template?.schema, slotId)
  if (!config) return fallbackText
  const text = (config.customText || '').trim()
  if (text) return text
  if (config.binding) return getMockValueByBinding(config.binding, typeHint)
  return fallbackText
}

const applyOpacityToColor = (color, opacity) => {
  if (!color) return undefined
  const o = typeof opacity === 'number' ? Math.max(0, Math.min(1, opacity)) : 1
  if (color === 'transparent') return `rgba(0, 0, 0, 0)`
  
  // 处理本身就是 rgba/rgb 的情况
  const match = String(color).match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*[\d.]+)?\)/)
  if (match) {
    return `rgba(${match[1]}, ${match[2]}, ${match[3]}, ${o})`
  }

  // 处理 hex 的情况
  const raw = String(color).trim()
  if (raw.startsWith('#')) {
    const hex = raw.slice(1)
    if ([3, 6].includes(hex.length)) {
      const expand = hex.length === 3 ? hex.split('').map(c => c + c).join('') : hex
      const r = Number.parseInt(expand.slice(0, 2), 16)
      const g = Number.parseInt(expand.slice(2, 4), 16)
      const b = Number.parseInt(expand.slice(4, 6), 16)
      if (![r, g, b].some(n => Number.isNaN(n))) {
        return `rgba(${r}, ${g}, ${b}, ${o})`
      }
    }
  }

  return color
}

const getSlotStyle = (slotId) => {
  const config = getSlotConfig(slotId)
  if (!config) return {}
  const style = config.style || {}
  const css = {}

  if (style.color) css.color = style.color
  if (style.fontSize) css.fontSize = `${style.fontSize}px`

  const bg = applyOpacityToColor(style.bgColor, style.opacity)
  if (bg && bg !== 'transparent') {
    css.backgroundColor = bg
    css.padding = '2px 6px'
    css.borderRadius = '4px'
  }
  return css
}

const getTemplateSlotStyle = (template, slotId) => {
  const config = getSlotConfigFromSchema(template?.schema, slotId)
  if (!config) return {}
  const style = config.style || {}
  const css = {}

  if (style.color) css.color = style.color
  if (style.fontSize) css.fontSize = `${style.fontSize}px`

  const bg = applyOpacityToColor(style.bgColor, style.opacity)
  if (bg && bg !== 'transparent') {
    css.backgroundColor = bg
    css.padding = '2px 6px'
    css.borderRadius = '4px'
  }
  return css
}

const getSkeletonPresetId = (schema) => {
  const presetId = schema?.skeletonPreset || defaultSkeletonPresetId
  return skeletonPresets.some(preset => preset.id === presetId) ? presetId : defaultSkeletonPresetId
}

const getWatermarkPresetClass = (schema, isCard = false) => {
  const presetId = getSkeletonPresetId(schema)
  return {
    [`preset-${presetId}`]: true,
    'is-card-preview': isCard
  }
}

const getWatermarkSurfaceStyle = (schema, isCard = false) => {
  const presetId = getSkeletonPresetId(schema)
  const baseBgColor = globalSettings.value.scene !== 'solid' ? globalSettings.value.bgColor : 'transparent'
  const paddingScale = isCard ? 0.68 : 1

  if (presetId === 'clean') {
    return {
      backgroundColor: 'transparent',
      padding: '0',
      borderRadius: '0'
    }
  }

  if (presetId === 'glass') {
    return {
      background: isCard
        ? 'linear-gradient(135deg, rgba(255,255,255,0.24), rgba(255,255,255,0.08))'
        : 'linear-gradient(135deg, rgba(255,255,255,0.22), rgba(255,255,255,0.08))',
      backdropFilter: 'blur(18px) saturate(140%)',
      WebkitBackdropFilter: 'blur(18px) saturate(140%)',
      border: '1px solid rgba(255,255,255,0.22)',
      boxShadow: isCard ? '0 6px 18px rgba(0,0,0,0.18)' : '0 12px 28px rgba(0,0,0,0.18)',
      padding: `${Math.round(14 * paddingScale)}px`,
      borderRadius: `${Math.round(16 * paddingScale)}px`
    }
  }

  if (presetId === 'compact') {
    return {
      background: baseBgColor === 'transparent' ? 'rgba(8, 12, 18, 0.76)' : baseBgColor,
      border: '1px solid rgba(255,255,255,0.08)',
      boxShadow: isCard ? '0 4px 12px rgba(0,0,0,0.2)' : '0 10px 24px rgba(0,0,0,0.16)',
      padding: `${Math.round(10 * paddingScale)}px`,
      borderRadius: `${Math.round(10 * paddingScale)}px`
    }
  }

  return {
    backgroundColor: baseBgColor,
    border: '1px solid rgba(255,255,255,0.06)',
    boxShadow: isCard ? '0 4px 12px rgba(0,0,0,0.16)' : '0 10px 26px rgba(0,0,0,0.18)',
    padding: `${Math.round(12 * paddingScale)}px`,
    borderRadius: `${Math.round(12 * paddingScale)}px`
  }
}

const getWatermarkPlacementStyle = (schema, isCard = false) => {
  const layout = normalizeLayout(schema?.layout)
  const surface = layout.surface
  const width = surface.width * 100
  const left = surface.x * 100
  const top = surface.y * 100

  return {
    position: 'absolute',
    left: `${left}%`,
    top: `${top}%`,
    right: 'auto',
    bottom: 'auto',
    width: `${width}%`,
    maxWidth: `${Math.max(20, 100 - left)}%`,
    boxSizing: 'border-box',
    lineHeight: surface.lineHeight,
    transformOrigin: 'top left',
    ...(isCard ? { fontSize: '68%' } : {})
  }
}

const getWatermarkRenderStyle = (schema, isCard = false) => {
  const layout = normalizeLayout(schema?.layout)
  const scale = isCard ? 0.68 : 1
  return {
    ...getWatermarkPlacementStyle(schema, isCard),
    ...getWatermarkSurfaceStyle(schema, isCard),
    padding: `${Math.round(layout.surface.padding * scale)}px`,
    borderRadius: `${Math.round(layout.surface.radius * scale)}px`
  }
}
</script>

<style>
.editor-drawer .el-drawer__body {
  padding: 0 !important;
}
</style>

<style scoped>
.page-container {
  padding: 100px 24px 24px 24px;
  width: 100%;
  height: 100%;
  box-sizing: border-box;
  background-color: #f5f7fa;
  display: flex;
  flex-direction: column;
}

.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
}

.header-titles .main-title {
  margin: 0;
  font-size: 24px;
  font-weight: 600;
  color: #303133;
}

.header-titles .sub-title {
  margin: 8px 0 0 0;
  font-size: 14px;
  color: #909399;
}

.header-controls {
  display: flex;
  gap: 16px;
  align-items: center;
}

.new-btn {
  background-color: #409eff;
  border-color: #409eff;
}

.gallery-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 24px;
  flex: 1;
  overflow-y: auto;
}

.watermark-card {
  background: #fff;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 12px 0 rgba(0,0,0,0.05);
  transition: all 0.3s;
  display: flex;
  flex-direction: column;
  position: relative;
}

.watermark-card:hover {
  box-shadow: 0 4px 16px 0 rgba(0,0,0,0.1);
  transform: translateY(-2px);
}

.card-thumbnail {
  height: 160px;
  background-color: #2c2c2c;
  position: relative;
  overflow: hidden;
}

.card-preview-canvas {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(180deg, rgba(20, 20, 20, 0.86), rgba(28, 28, 28, 0.96)),
    radial-gradient(circle at 20% 20%, rgba(255,255,255,0.06), transparent 40%);
}

.card-preview-frame {
  position: absolute;
  inset: 12% 10%;
  border: 1px dashed rgba(255, 255, 255, 0.12);
  overflow: hidden;
}

.card-preview-watermark {
  position: absolute;
  left: 24px;
  right: 24px;
  bottom: 22px;
  color: #fff;
  text-shadow: 1px 1px 2px rgba(0,0,0,0.8);
}

.card-preview-watermark.preset-clean {
  left: 20px;
  right: 20px;
  bottom: 18px;
}

.card-preview-watermark.preset-compact {
  left: 18px;
  right: 18px;
  bottom: 18px;
}

.card-preview-title {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.25;
  margin-bottom: 6px;
  display: inline-block;
}

.card-preview-subtitle {
  display: block;
  font-size: 11px;
  margin-bottom: 8px;
  opacity: 0.9;
}

.card-preview-fields {
  font-size: 11px;
  line-height: 1.45;
}

.card-preview-field {
  opacity: 0.92;
}

.card-preview-field-text {
  display: inline-block;
}

.card-preview-bottom {
  display: inline-block;
  margin-top: 8px;
  font-size: 10px;
  opacity: 0.9;
}

.mockup-title {
  display: block;
  font-size: 14px;
  font-weight: bold;
}

.mockup-time {
  display: block;
  font-size: 12px;
  margin-top: 4px;
}

.card-hover-actions {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  opacity: 0;
  transition: opacity 0.3s;
  z-index: 10;
}

.card-thumbnail:hover .card-hover-actions {
  opacity: 1;
}

.card-info {
  padding: 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.card-name {
  font-size: 14px;
  font-weight: 500;
  color: #303133;
}

.card-title-preview {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
  padding: 0 16px 16px;
}

.template-info-form {
  margin-bottom: 16px;
}

.editor-layout {
  height: 100vh;
  display: flex;
  flex-direction: column;
  background-color: #f0f2f5;
}

.editor-header {
  height: 56px;
  background: #fff;
  border-bottom: 1px solid #dcdfe6;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 24px;
  box-sizing: border-box;
  flex-shrink: 0;
}

.editor-title {
  font-size: 16px;
  font-weight: bold;
  color: #303133;
}

.editor-body {
  flex: 1;
  display: flex;
  overflow: hidden;
}

.editor-left {
  width: 280px;
  background: #fff;
  border-right: 1px solid #dcdfe6;
  padding: 20px;
  box-sizing: border-box;
  overflow-y: auto;
}

.editor-left h3, .editor-right h3 {
  margin-top: 0;
  margin-bottom: 16px;
  font-size: 15px;
  color: #303133;
}

.skeleton-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.skeleton-item {
  padding: 12px;
  border: 1px solid #dcdfe6;
  border-radius: 4px;
  cursor: pointer;
  text-align: left;
  transition: all 0.2s;
}

.skeleton-item-title {
  font-size: 14px;
  font-weight: 600;
  color: #303133;
}

.skeleton-item-desc {
  margin-top: 6px;
  font-size: 12px;
  line-height: 1.5;
  color: #909399;
}

.skeleton-item:hover {
  border-color: #c6e2ff;
}

.skeleton-item.active {
  border-color: #409eff;
  background: #ecf5ff;
}

.skeleton-item.active .skeleton-item-title {
  color: #409eff;
}

.skeleton-item.active .skeleton-item-desc {
  color: #6aa9ff;
}

.setting-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  font-size: 14px;
  color: #606266;
}

.editor-middle {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: #e4e7ed;
  overflow-y: auto;
  padding: 8px 12px;
  min-width: 360px;
}

.iphone-mockup {
  width: 320px;
  height: 650px;
  background: #111;
  border-radius: 40px;
  padding: 12px;
  box-sizing: border-box;
  box-shadow: 0 10px 30px rgba(0,0,0,0.2);
}

.iphone-screen {
  width: 100%;
  height: 100%;
  border-radius: 30px;
  overflow: hidden;
  position: relative;
  background-size: cover;
  background-position: center;
  transition: background-image 0.3s;
}

.scene-solid {
  background-image: none;
}

.scene-day_construction {
  background-image: url('https://images.unsplash.com/photo-1541888087458-924b17e0b57d?auto=format&fit=crop&q=80&w=320&h=650');
}

.scene-night_street {
  background-image: url('https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&q=80&w=320&h=650');
}

.scene-blueprint {
  background-image: url('https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&q=80&w=320&h=650');
}

.scene-radio-group {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.iphone-camera-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 1;
}

.preview-content {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  padding: 20px;
  z-index: 2;
}

.preview-watermark {
  color: #fff;
  text-shadow: 1px 1px 2px rgba(0,0,0,0.8);
}

.preview-watermark.preset-clean {
  max-width: 100%;
}

.preview-watermark.preset-compact .preview-title {
  margin-bottom: 6px;
}

.preview-watermark.preset-compact .preview-subtitle {
  margin-bottom: 8px;
}

.preview-watermark.preset-compact .preview-fields {
  line-height: 1.45;
}

.preview-watermark.preset-glass {
  color: #f8fbff;
}

.preview-title {
  font-size: 18px;
  font-weight: bold;
  margin-bottom: 8px;
  display: block;
}

.preview-subtitle {
  font-size: 13px;
  margin-bottom: 10px;
  display: block;
}

.preview-fields {
  font-size: 13px;
  line-height: 1.6;
}

.preview-field {
  opacity: 0.9;
}

.preview-field-text {
  display: inline-block;
}

.preview-bottom {
  margin-top: 10px;
  font-size: 12px;
  display: inline-block;
}

.editor-right {
  width: 600px;
  background: #fff;
  border-left: 1px solid #dcdfe6;
  padding: 0;
  box-sizing: border-box;
  overflow: hidden;
  display: flex;
}

.slot-list-panel {
  flex: 1;
  padding: 20px;
  box-sizing: border-box;
  overflow-y: auto;
  transition: flex-basis 0.2s ease;
}

.editor-right.has-detail .slot-list-panel {
  flex: 0 0 280px;
}

.slot-detail-panel {
  flex: 0 0 320px;
  border-left: 1px solid #ebeef5;
  padding: 16px;
  box-sizing: border-box;
  overflow-y: auto;
  position: relative;
}

.slot-detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.slot-detail-title {
  font-size: 14px;
  font-weight: 600;
  color: #303133;
}

.slot-detail-form :deep(.el-form-item) {
  margin-bottom: 12px;
}

.slot-section-title {
  margin: 10px 0 10px 0;
  font-size: 13px;
  font-weight: 600;
  color: #606266;
}

.slot-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.slot-card {
  border: 1px solid #ebeef5;
  border-radius: 6px;
  background-color: #fff;
  transition: box-shadow 0.3s;
}

.slot-card:hover {
  box-shadow: 0 2px 12px 0 rgba(0,0,0,0.1);
}

.slot-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  background-color: #f5f7fa;
  border-bottom: 1px solid #ebeef5;
  border-radius: 6px 6px 0 0;
}

.slot-header-left {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}

.slot-header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.slot-action-btn {
  padding: 0 6px;
}

.slot-summary {
  font-size: 12px;
  color: #909399;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 150px;
}

.drag-handle {
  cursor: grab;
  color: #909399;
}

.drag-handle:active {
  cursor: grabbing;
}

.slot-title {
  font-size: 14px;
  font-weight: 500;
  color: #303133;
}

.slot-body {
  padding: 12px;
}

.slot-type {
  font-size: 13px;
  color: #606266;
}

</style>
