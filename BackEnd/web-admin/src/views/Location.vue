<template>
  <div class="page-container fade-in-up">
    <!-- 主内容区 -->
    <div class="location-content">
      <!-- 地图容器 -->
      <div class="map-container module-card">
        <!-- 悬浮左上角：图层与在线人数 -->
        <div class="map-floating-left">
          <div class="online-badge">
            <span class="online-dot pulse"></span>
            <span>在线 <strong>{{ onlineCount }}</strong> 人</span>
          </div>
          <div class="layer-toggles">
            <label class="layer-toggle" :class="{ active: showPersonnel }">
              <input type="checkbox" v-model="showPersonnel" @change="updateAllLayers" />
              <span class="toggle-dot personnel-dot"></span>
              在线人员
            </label>
            <label class="layer-toggle" :class="{ active: showProjects }">
              <input type="checkbox" v-model="showProjects" @change="updateAllLayers" />
              <span class="toggle-dot project-dot"></span>
              项目围栏
            </label>
            <label class="layer-toggle" :class="{ active: showDevices }">
              <input type="checkbox" v-model="showDevices" @change="updateAllLayers" />
              <span class="toggle-dot device-dot"></span>
              硬件设备
            </label>
          </div>
        </div>

        <!-- 悬浮右上角：全局刷新 -->
        <el-button 
          class="map-floating-right" 
          :icon="Refresh" 
          circle 
          @click="refreshAll" 
          :loading="loading"
          title="刷新全局"
        />

        <div id="amap-container" class="map-box"></div>
        <div v-if="!mapReady" class="map-placeholder">
          <el-icon :size="48" color="#5f6477"><Location /></el-icon>
          <p>全景地图加载中…</p>
          <p class="map-tip">正在初始化三维定位图层引擎</p>
        </div>
        <!-- 图例 -->
        <div class="map-legend" v-if="mapReady">
          <div class="legend-item" v-if="showPersonnel">
            <span class="legend-dot" style="background: #3b82f6"></span>在线人员
          </div>
          <div class="legend-item" v-if="showProjects">
            <span class="legend-dot" style="background: #10b981"></span>项目围栏
          </div>
          <div class="legend-item" v-if="showDevices">
            <span class="legend-dot" style="background: #f59e0b"></span>硬件设备
          </div>
        </div>
      </div>

      <!-- 右侧信息面板 -->
      <div class="side-panel">
        <!-- 人员列表 -->
        <div class="panel-card" v-if="showPersonnel">
          <div class="panel-header">
            <div class="panel-title-wrap">
              <span>在线人员</span>
              <el-tag type="primary" size="small" effect="dark" round>{{ locations.length }}</el-tag>
            </div>
            <el-select v-model="selectedProject" placeholder="按项目筛选" size="small" clearable style="width: 140px" @change="loadLocations">
              <el-option v-for="p in projectList" :key="p.id" :label="p.name" :value="p.id" />
            </el-select>
          </div>
          <div class="panel-body">
            <div
              v-for="loc in locations"
              :key="loc.user_id"
              class="list-item"
              :class="{ active: selectedUser === loc.user_id }"
              @click="focusUser(loc)"
            >
              <el-avatar :size="34" style="background: var(--gradient-blue); font-size: 13px; flex-shrink: 0;">
                {{ loc.user_name?.charAt(0) }}
              </el-avatar>
              <div class="item-info">
                <div class="item-name">
                  <span class="online-dot"></span>{{ loc.user_name }}
                </div>
                <div class="item-sub">{{ loc.address || '定位更新中…' }}</div>
                <div class="item-time">{{ formatTime(loc.created_at) }}</div>
              </div>
            </div>
            <div v-if="locations.length === 0" class="empty-tip">
              <el-icon :size="28" color="#555b6e"><User /></el-icon>
              <p>暂无在线人员</p>
            </div>
          </div>
        </div>

        <!-- 项目列表 -->
        <div class="panel-card" v-if="showProjects">
          <div class="panel-header">
            <span>项目工地</span>
            <el-tag type="success" size="small" effect="dark" round>{{ projectsWithCoords.length }}</el-tag>
          </div>
          <div class="panel-body">
            <div
              v-for="p in projectsWithCoords"
              :key="p.id"
              class="list-item"
              @click="focusProject(p)"
            >
              <div class="item-icon project-icon">
                <el-icon><OfficeBuilding /></el-icon>
              </div>
              <div class="item-info">
                <div class="item-name project-name">{{ p.name }}</div>
                <div class="item-sub">围栏半径 {{ p.radius }}m</div>
              </div>
            </div>
            <div v-if="projectsWithCoords.length === 0" class="empty-tip">
              <el-icon :size="28" color="#555b6e"><OfficeBuilding /></el-icon>
              <p>暂无已设置坐标的项目</p>
            </div>
          </div>
        </div>

        <!-- 设备列表 -->
        <div class="panel-card" v-if="showDevices">
          <div class="panel-header">
            <span>硬件设备</span>
            <el-tag type="warning" size="small" effect="dark" round>{{ devicesWithCoords.length }}</el-tag>
          </div>
          <div class="panel-body">
            <div
              v-for="d in devicesWithCoords"
              :key="d.id"
              class="list-item"
              @click="focusDevice(d)"
            >
              <div class="item-icon device-icon">
                <el-icon><Cpu /></el-icon>
              </div>
              <div class="item-info">
                <div class="item-name">{{ d.name }}</div>
                <div class="item-sub">{{ getTypeName(d.type) }}</div>
                <div class="item-time">{{ d.last_active ? '活跃: ' + formatTime(d.last_active) : '尚未激活' }}</div>
              </div>
              <el-tag :type="d.status === 1 ? 'success' : 'danger'" size="small" effect="dark">
                {{ d.status === 1 ? '在线' : '离线' }}
              </el-tag>
            </div>
            <div v-if="devicesWithCoords.length === 0" class="empty-tip">
              <el-icon :size="28" color="#555b6e"><Cpu /></el-icon>
              <p>暂无已设置坐标的设备</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { getLatestLocations, getOnlineCount } from '@/api/location'
import { getAllProjects } from '@/api/projects'
import { getDevices } from '@/api/devices'
import { Refresh, User, OfficeBuilding, Cpu } from '@element-plus/icons-vue'

// ---- 数据状态 ----
const locations = ref([])
const projectList = ref([])
const deviceList = ref([])
const selectedProject = ref('')
const selectedUser = ref(null)
const onlineCount = ref(0)
const loading = ref(false)

// ---- 图层开关 ----
const showPersonnel = ref(true)
const showProjects = ref(true)
const showDevices = ref(true)

// ---- 地图状态 ----
const mapReady = ref(false)
let map = null
let personnelMarkers = []
let projectCircles = []
let projectMarkers = []
let deviceMarkers = []
let refreshTimer = null
let themeObserver = null

// 根据当前主题返回地图样式
function getMapStyle() {
  const isDark = document.documentElement.classList.contains('dark')
  console.log('当前主题状态:', isDark ? '暗色' : '亮色')
  return isDark ? 'amap://styles/dark' : 'amap://styles/normal'
}

// ---- 计算带坐标的项目/设备 ----
const projectsWithCoords = computed(() =>
  projectList.value.filter(p => p.latitude && p.longitude)
)
const devicesWithCoords = computed(() =>
  deviceList.value.filter(d => d.latitude && d.longitude)
)

// ---- 生命周期 ----
onMounted(() => {
  initMap()
  refreshAll()
  refreshTimer = setInterval(refreshAll, 30000)

  // 监听主题切换，同步地图瓦片风格
  themeObserver = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
        if (map && mapReady.value) {
          try {
            const newStyle = getMapStyle()
            console.log('切换地图样式:', newStyle)
            map.setMapStyle(newStyle)
          } catch (e) {
            console.warn('地图样式切换失败:', e)
          }
        }
      }
    })
  })
  themeObserver.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class']
  })
})

onUnmounted(() => {
  if (refreshTimer) clearInterval(refreshTimer)
  if (themeObserver) themeObserver.disconnect()
  if (map) map.destroy()
})

// ---- 数据加载 ----
async function refreshAll() {
  loading.value = true
  try {
    await Promise.all([loadLocations(), loadProjects(), loadDeviceData()])
  } finally {
    loading.value = false
  }
}

async function loadLocations() {
  try {
    const params = {}
    if (selectedProject.value) params.project_id = selectedProject.value
    const res = await getLatestLocations(params)
    if (res.code === 200) {
      // 按 user_id 去重，同一用户只保留最新的一条（created_at 最大）
      const uniqueMap = new Map()
      for (const loc of res.data) {
        const existing = uniqueMap.get(loc.user_id)
        if (!existing || new Date(loc.created_at) > new Date(existing.created_at)) {
          uniqueMap.set(loc.user_id, loc)
        }
      }
      locations.value = Array.from(uniqueMap.values())
    }

    const countRes = await getOnlineCount()
    if (countRes.code === 200) onlineCount.value = countRes.data.online

    drawPersonnel()
  } catch (e) { console.warn('位置加载失败', e) }
}

async function loadProjects() {
  try {
    const res = await getAllProjects()
    if (res.code === 200) projectList.value = res.data
    drawProjects()
  } catch (e) { console.warn('项目加载失败', e) }
}

async function loadDeviceData() {
  try {
    const res = await getDevices({ pageSize: 999 })
    if (res.code === 200) deviceList.value = res.data.list || []
    drawDevices()
  } catch (e) { console.warn('设备加载失败', e) }
}

// ---- 地图初始化 ----
function initMap() {
  // AMap 已在 index.html 全局加载，直接使用
  if (window.AMap) {
    createMap()
  } else {
    console.warn('高德地图 API 尚未加载，等待初始化...')
    // 如果全局脚本还没加载完，轮询等待
    const wait = setInterval(() => {
      if (window.AMap) {
        clearInterval(wait)
        createMap()
      }
    }, 200)
  }
}

function createMap() {
  try {
    map = new window.AMap.Map('amap-container', {
      zoom: 8,
      center: [106.713478, 26.578343],
      mapStyle: getMapStyle(),
      viewMode: '2D',
    })
    
    map.on('complete', () => {
      console.log('地图加载完成')
      mapReady.value = true
      updateAllLayers()
    })
    
    map.on('error', (e) => {
      console.error('地图加载错误:', e)
      // 如果样式加载失败，回退到默认样式
      if (map) {
        map.setMapStyle(null)
        mapReady.value = true
        updateAllLayers()
      }
    })
  } catch (e) {
    console.error('地图创建失败:', e)
  }
}

// ---- 图层刷新总控 ----
function updateAllLayers() {
  drawPersonnel()
  drawProjects()
  drawDevices()
  fitAllView()
}

// ---- 🔵 人员图层 ----
function drawPersonnel() {
  if (!map) return
  personnelMarkers.forEach(m => map.remove(m))
  personnelMarkers = []
  if (!showPersonnel.value) return

  locations.value.forEach(loc => {
    if (!loc.latitude || !loc.longitude) return
    const marker = new window.AMap.Marker({
      position: [loc.longitude, loc.latitude],
      title: loc.user_name,
      content: `<div class="custom-marker personnel-marker">${loc.user_name?.charAt(0) || '?'}</div>`,
      offset: new window.AMap.Pixel(-16, -16),
      zIndex: 120
    })
    const infoWindow = new window.AMap.InfoWindow({
      content: `<div class="amap-info-box">
        <strong>${loc.user_name}</strong>
        <p>${loc.address || '坐标更新中'}</p>
        <p style="opacity:0.6;font-size:11px">${formatTime(loc.created_at)}</p>
      </div>`,
      offset: new window.AMap.Pixel(0, -36)
    })
    marker.on('click', () => {
      infoWindow.open(map, marker.getPosition())
      selectedUser.value = loc.user_id
    })
    personnelMarkers.push(marker)
    map.add(marker)
  })
}

// ---- 🟢 项目围栏图层 ----
function drawProjects() {
  if (!map) return
  projectCircles.forEach(c => map.remove(c))
  projectMarkers.forEach(m => map.remove(m))
  projectCircles = []
  projectMarkers = []
  if (!showProjects.value) return

  projectsWithCoords.value.forEach(p => {
    const center = [p.longitude, p.latitude]

    // 围栏圆圈
    const circle = new window.AMap.Circle({
      center,
      radius: p.radius || 500,
      strokeColor: '#10b981',
      strokeOpacity: 0.8,
      strokeWeight: 2,
      fillColor: '#10b981',
      fillOpacity: 0.08,
      zIndex: 50
    })

    // 项目标记
    const marker = new window.AMap.Marker({
      position: center,
      content: `<div class="custom-marker project-marker"><svg viewBox="0 0 24 24" width="14" height="14" fill="white"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg></div>`,
      offset: new window.AMap.Pixel(-16, -16),
      title: p.name,
      zIndex: 110
    })

    const infoWindow = new window.AMap.InfoWindow({
      content: `<div class="amap-info-box">
        <strong style="color:#10b981">📍 ${p.name}</strong>
        <p>打卡围栏半径：${p.radius || 500}m</p>
      </div>`,
      offset: new window.AMap.Pixel(0, -36)
    })
    marker.on('click', () => infoWindow.open(map, marker.getPosition()))

    projectCircles.push(circle)
    projectMarkers.push(marker)
    map.add([circle, marker])
  })
}

// ---- 🟠 设备图层 ----
function drawDevices() {
  if (!map) return
  deviceMarkers.forEach(m => map.remove(m))
  deviceMarkers = []
  if (!showDevices.value) return

  devicesWithCoords.value.forEach(d => {
    const marker = new window.AMap.Marker({
      position: [d.longitude, d.latitude],
      content: `<div class="custom-marker device-marker ${d.status === 1 ? 'online' : 'offline'}">
        <svg viewBox="0 0 24 24" width="12" height="12" fill="white"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>
      </div>`,
      offset: new window.AMap.Pixel(-16, -16),
      title: d.name,
      zIndex: 100
    })

    const infoWindow = new window.AMap.InfoWindow({
      content: `<div class="amap-info-box">
        <strong style="color:#f59e0b">⚙️ ${d.name}</strong>
        <p>${getTypeName(d.type)}</p>
        <p>状态：${d.status === 1 ? '🟢 在线' : '🔴 离线'}</p>
        ${d.last_active ? `<p style="opacity:0.6;font-size:11px">最后活跃：${formatTime(d.last_active)}</p>` : ''}
      </div>`,
      offset: new window.AMap.Pixel(0, -36)
    })
    marker.on('click', () => infoWindow.open(map, marker.getPosition()))

    deviceMarkers.push(marker)
    map.add(marker)
  })
}

// ---- 自适应视野 ----
function fitAllView() {
  if (!map) return
  const all = [...personnelMarkers, ...projectMarkers, ...deviceMarkers, ...projectCircles]
  if (all.length > 0) {
    map.setFitView(all, false, [80, 80, 80, 80])
  }
}

// ---- 聚焦操作 ----
function focusUser(loc) {
  selectedUser.value = loc.user_id
  if (map && loc.latitude && loc.longitude) {
    map.setZoomAndCenter(16, [loc.longitude, loc.latitude])
  }
}

function focusProject(p) {
  if (map && p.latitude && p.longitude) {
    map.setZoomAndCenter(15, [p.longitude, p.latitude])
  }
}

function focusDevice(d) {
  if (map && d.latitude && d.longitude) {
    map.setZoomAndCenter(17, [d.longitude, d.latitude])
  }
}

// ---- 工具函数 ----
function formatTime(t) {
  if (!t) return ''
  // 后端返回本地时间字符串，替换空格为T确保浏览器按本地时间解析
  const d = new Date(typeof t === 'string' ? t.replace(' ', 'T') : t)
  return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`
}

function getTypeName(type) {
  const map = { checkpoint: '考勤闸机', beacon: '蓝牙信标', camera: '监控摄头', other: '其他设备' }
  return map[type] || '未知'
}
</script>

<style scoped>
/* 悬浮控制层 - 左上角 */
.map-floating-left {
  position: absolute;
  top: 16px;
  left: 16px;
  z-index: 200;
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 10px 16px;
  border-radius: var(--radius-md);
  background: var(--bg-card);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid var(--border-color);
  box-shadow: var(--shadow-sm);
  flex-wrap: wrap;
}

/* 悬浮按钮 - 右上角 */
.map-floating-right {
  position: absolute;
  top: 16px;
  right: 16px;
  z-index: 200;
  background: var(--bg-card) !important;
  backdrop-filter: blur(12px) !important;
  -webkit-backdrop-filter: blur(12px) !important;
  border: 1px solid var(--border-color) !important;
  box-shadow: var(--shadow-sm) !important;
  color: var(--text-primary) !important;
  transition: var(--transition);
}

.map-floating-right:hover {
  background: var(--bg-card-hover) !important;
  transform: scale(1.05);
}

.online-badge {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: var(--text-secondary);
}

/* 图层切换 */
.layer-toggles {
  display: flex;
  gap: 12px;
}

.layer-toggle {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: var(--text-muted);
  cursor: pointer;
  transition: var(--transition);
  user-select: none;
  padding: 4px 10px;
  border-radius: 20px;
  border: 1px solid var(--border-light);
}

.layer-toggle input {
  display: none;
}

.layer-toggle.active {
  color: var(--text-primary);
  border-color: var(--border-color);
  background: rgba(255,255,255,0.04);
}

.toggle-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.personnel-dot { background: #3b82f6; }
.project-dot { background: #10b981; }
.device-dot { background: #f59e0b; }

/* 主布局 */
.location-content {
  display: grid;
  grid-template-columns: 1fr 320px;
  gap: 16px;
  height: calc(100vh - 132px); /* 适应顶部与底部边距 */
  min-height: 500px;
}

/* 地图 */
.map-container {
  position: relative;
  padding: 0;
  overflow: hidden;
  min-height: 500px;
}

.map-box {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.map-placeholder {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: var(--bg-card);
  gap: 12px;
  color: var(--text-secondary);
}

.map-tip {
  font-size: 12px;
  color: var(--text-muted);
}

/* 地图图例 */
.map-legend {
  position: absolute;
  bottom: 16px;
  left: 16px;
  background: rgba(5, 5, 8, 0.7);
  backdrop-filter: blur(12px);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  padding: 10px 14px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: var(--text-secondary);
}

.legend-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

/* 右侧面板 */
.side-panel {
  display: flex;
  flex-direction: column;
  gap: 12px;
  overflow-y: auto;
}

.panel-card {
  background: var(--bg-card);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
}

.panel-header {
  padding: 12px 16px;
  border-bottom: 1px solid var(--border-color);
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-weight: 600;
  font-size: 13px;
  flex-shrink: 0;
}

.panel-title-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
}

.panel-body {
  flex: 1;
  overflow-y: auto;
  padding: 6px;
  max-height: 240px;
}

/* 列表项 */
.list-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px;
  border-radius: 8px;
  cursor: pointer;
  transition: var(--transition);
}

.list-item:hover,
.list-item.active {
  background: rgba(79, 140, 255, 0.08);
}

.item-info {
  flex: 1;
  min-width: 0;
}

.item-name {
  font-size: 13px;
  font-weight: 500;
  color: var(--text-primary);
  display: flex;
  align-items: center;
  gap: 4px;
}

.project-name { color: #10b981; }

.item-sub {
  font-size: 11px;
  color: var(--text-secondary);
  margin-top: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.item-time {
  font-size: 10px;
  color: var(--text-muted);
  margin-top: 1px;
}

.item-icon {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 16px;
}

.project-icon {
  background: rgba(16, 185, 129, 0.15);
  color: #10b981;
}

.device-icon {
  background: rgba(245, 158, 11, 0.15);
  color: #f59e0b;
}

.empty-tip {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 24px;
  gap: 6px;
  color: var(--text-muted);
  font-size: 12px;
}

/* 动画 */
.online-dot.pulse {
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.6; transform: scale(1.2); }
}
</style>

<!-- 全局自定义地图标记样式（非scoped） -->
<style>
.custom-marker {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 13px;
  font-weight: 600;
  color: white;
  border: 2px solid rgba(255,255,255,0.5);
  box-shadow: 0 2px 12px rgba(0,0,0,0.4);
}

.personnel-marker {
  background: linear-gradient(135deg, #3b82f6, #6366f1);
}

.project-marker {
  background: linear-gradient(135deg, #10b981, #059669);
}

.device-marker {
  background: linear-gradient(135deg, #f59e0b, #d97706);
}

.device-marker.offline {
  background: linear-gradient(135deg, #6b7280, #4b5563);
  opacity: 0.7;
}

.amap-info-box {
  background: rgba(10, 12, 24, 0.95);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 10px;
  padding: 10px 14px;
  color: #f1f3f5;
  font-size: 13px;
  min-width: 140px;
  backdrop-filter: blur(12px);
}

.amap-info-box strong {
  display: block;
  margin-bottom: 4px;
  font-size: 14px;
}

.amap-info-box p {
  margin: 2px 0;
  color: #8b92a5;
  font-size: 12px;
}
</style>
