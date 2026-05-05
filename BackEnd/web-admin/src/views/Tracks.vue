<template>
  <div class="page-container fade-in-up">
    <div class="track-content">
      <!-- 左侧地图 -->
      <div class="map-wrapper">
        <!-- 悬浮左上角：筛选栏 -->
        <div class="map-floating-bar">
          <el-select v-model="filters.user_id" placeholder="选择人员" filterable style="width: 160px">
            <el-option v-for="u in userList" :key="u.id" :label="u.name" :value="u.id" />
          </el-select>
          <el-date-picker
            v-model="filters.date"
            type="date"
            placeholder="选择日期"
            value-format="YYYY-MM-DD"
            :disabled-date="(date) => date > new Date()"
            style="width: 140px"
          />
          <el-button type="primary" :icon="Search" :loading="loading" @click="loadTrack" :disabled="!filters.user_id || !filters.date">查询</el-button>
        </div>

        <div id="track-map" class="map-box"></div>

        <!-- 播放控制条 -->
        <div v-if="trackData && trackData.points && trackData.points.length > 0" class="playback-bar">
          <el-button :icon="isPlaying ? 'VideoPause' : 'VideoPlay'" circle size="small" @click="togglePlay" />
          <el-slider
            v-model="playProgress"
            :max="trackData.points.length - 1"
            :show-tooltip="false"
            style="flex:1;margin:0 12px"
            @input="onSeek"
          />
          <span style="font-size:12px;color:var(--text-secondary);white-space:nowrap">
            {{ playProgress + 1 }}/{{ trackData.points.length }}
          </span>
          <el-select v-model="playSpeed" size="small" style="width:72px;margin-left:12px">
            <el-option label="1x" :value="1" />
            <el-option label="2x" :value="2" />
            <el-option label="4x" :value="4" />
          </el-select>
        </div>
      </div>

      <!-- 右侧信息面板 -->
      <div class="side-panel">
        <div v-if="!trackData" class="panel-card empty-state">
          <el-icon :size="48" style="opacity:0.3"><MapLocation /></el-icon>
          <p>选择人员和日期后查询轨迹</p>
        </div>

        <template v-else>
          <!-- 人员信息 -->
          <div class="panel-card">
            <div class="panel-header">人员信息</div>
            <div class="panel-body">
              <div style="display:flex;align-items:center;gap:12px;">
                <el-avatar :size="44" style="background:var(--gradient-blue);font-size:16px;color:#fff">
                  {{ selectedUserName?.charAt(0) || '?' }}
                </el-avatar>
                <div>
                  <div style="font-weight:700;font-size:15px;color:var(--text-primary)">{{ selectedUserName }}</div>
                  <div style="font-size:12px;color:var(--text-secondary)">{{ filters.date }}</div>
                </div>
              </div>
            </div>
          </div>

          <!-- 统计 -->
          <div class="panel-card stats-grid">
            <div class="stat-box">
              <div class="stat-num" style="color:var(--accent-blue)">{{ trackData.total_distance || '0' }}</div>
              <div class="stat-label">总里程(km)</div>
            </div>
            <div class="stat-box">
              <div class="stat-num" style="color:var(--accent-green)">{{ trackData.points?.length || 0 }}</div>
              <div class="stat-label">轨迹点数</div>
            </div>
          </div>

          <!-- 停留点 -->
          <div class="panel-card" v-if="trackData.stops && trackData.stops.length > 0">
            <div class="panel-header">
              <span><el-icon><Location /></el-icon> 停留点 ({{ trackData.stops.length }})</span>
            </div>
            <div class="panel-body stops-list">
              <div
                v-for="(stop, idx) in trackData.stops"
                :key="idx"
                class="stop-item"
                @click="focusStop(stop)"
              >
                <div class="stop-title">{{ stop.address || `停留点 ${idx + 1}` }}</div>
                <div class="stop-meta">{{ stop.start_time }} ~ {{ stop.end_time }} · {{ stop.duration }}分钟</div>
              </div>
            </div>
          </div>

          <!-- 打卡记录 -->
          <div class="panel-card" v-if="trackData.checkins && trackData.checkins.length > 0">
            <div class="panel-header">
              <span><el-icon><Clock /></el-icon> 打卡记录 ({{ trackData.checkins.length }})</span>
            </div>
            <div class="panel-body checkins-list">
              <div
                v-for="(c, idx) in trackData.checkins"
                :key="idx"
                class="checkin-item"
              >
                <div class="checkin-top">
                  <el-tag :type="c.type === 'clock_in' ? 'success' : 'warning'" size="small" effect="dark" round>
                    {{ c.type === 'clock_in' ? '上班' : '下班' }}
                  </el-tag>
                  <span class="checkin-time">{{ c.time }}</span>
                </div>
                <div class="checkin-addr">{{ c.address }}</div>
              </div>
            </div>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, nextTick, watch, onUnmounted } from 'vue'
import { getTrack } from '@/api/tracks'
import { getUsers } from '@/api/users'
import { ElMessage } from 'element-plus'
import { Search, MapLocation, Location, Clock } from '@element-plus/icons-vue'

const loading = ref(false)
const userList = ref([])
const trackData = ref(null)
const mapContainer = ref(null)

const filters = reactive({
  user_id: null,
  date: new Date().toISOString().slice(0, 10)
})

// 播放控制
const isPlaying = ref(false)
const playProgress = ref(0)
const playSpeed = ref(1)
let playTimer = null
let map = null
let trackLine = null
let markers = []
let movingMarker = null

const selectedUserName = ref('')

onMounted(() => {
  loadUsers()
  initMap()
})

onUnmounted(() => {
  stopPlay()
})

async function loadUsers() {
  try {
    const res = await getUsers({ pageSize: 999, status: 1 })
    userList.value = res.data.list || []
  } catch (e) {
    console.warn('加载用户列表失败:', e)
  }
}

function initMap() {
  nextTick(() => {
    if (window.AMap) {
      createMap()
    } else {
      // 动态加载高德地图 JS API
      const script = document.createElement('script')
      script.src = 'https://webapi.amap.com/maps?v=2.0&key=your_amap_web_key_here'
      script.onload = () => createMap()
      document.head.appendChild(script)
    }
  })
}

function createMap() {
  try {
    map = new window.AMap.Map('track-map', {
      zoom: 14,
      mapStyle: 'amap://styles/dark'
    })
  } catch (e) {
    console.error('地图初始化失败:', e)
  }
}

async function loadTrack() {
  if (!filters.user_id || !filters.date) return
  const user = userList.value.find(u => u.id === filters.user_id)
  selectedUserName.value = user?.name || ''
  loading.value = true
  stopPlay()
  try {
    const res = await getTrack(filters.user_id, filters.date)
    trackData.value = res.data
    await nextTick()
    drawTrack()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '加载轨迹失败')
    trackData.value = null
  } finally {
    loading.value = false
  }
}

function drawTrack() {
  if (!map || !trackData.value) return
  // 清除旧覆盖物
  map.clearMap()
  markers = []
  trackLine = null
  movingMarker = null

  const points = trackData.value.points || []
  if (points.length === 0) return

  const path = points.map(p => new window.AMap.LngLat(p.longitude, p.latitude))

  // 绘制轨迹线
  trackLine = new window.AMap.Polyline({
    path,
    strokeColor: '#3B82F6',
    strokeWeight: 5,
    strokeOpacity: 0.8,
    lineJoin: 'round'
  })
  map.add(trackLine)

  // 起点
  const startMarker = new window.AMap.Marker({
    position: path[0],
    content: '<div style="width:16px;height:16px;background:#22C55E;border:3px solid #fff;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3)"></div>',
    offset: new window.AMap.Pixel(-8, -8)
  })
  map.add(startMarker)
  markers.push(startMarker)

  // 终点
  if (path.length > 1) {
    const endMarker = new window.AMap.Marker({
      position: path[path.length - 1],
      content: '<div style="width:16px;height:16px;background:#EF4444;border:3px solid #fff;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3)"></div>',
      offset: new window.AMap.Pixel(-8, -8)
    })
    map.add(endMarker)
    markers.push(endMarker)
  }

  // 停留点标记
  const stops = trackData.value.stops || []
  for (const stop of stops) {
    if (stop.longitude && stop.latitude) {
      const stopMarker = new window.AMap.Marker({
        position: new window.AMap.LngLat(stop.longitude, stop.latitude),
        content: `<div style="width:20px;height:20px;background:#F59E0B;border:3px solid #fff;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3)"></div>`,
        offset: new window.AMap.Pixel(-10, -10)
      })
      map.add(stopMarker)
      markers.push(stopMarker)
    }
  }

  // 自适应视野
  map.setFitView(markers.concat([trackLine]))

  // 移动小车图标
  movingMarker = new window.AMap.Marker({
    position: path[0],
    content: '<div style="font-size:20px">🚗</div>',
    offset: new window.AMap.Pixel(-10, -10),
    zIndex: 200
  })
  map.add(movingMarker)
}

function togglePlay() {
  if (isPlaying.value) {
    stopPlay()
  } else {
    startPlay()
  }
}

function startPlay() {
  if (!trackData.value?.points?.length) return
  isPlaying.value = true
  const points = trackData.value.points
  if (playProgress.value >= points.length - 1) playProgress.value = 0

  playTimer = setInterval(() => {
    if (playProgress.value >= points.length - 1) {
      stopPlay()
      return
    }
    playProgress.value++
    updateMovingMarker()
  }, 1000 / playSpeed.value)
}

function stopPlay() {
  isPlaying.value = false
  if (playTimer) {
    clearInterval(playTimer)
    playTimer = null
  }
}

function onSeek() {
  updateMovingMarker()
}

function updateMovingMarker() {
  if (!movingMarker || !trackData.value?.points) return
  const p = trackData.value.points[playProgress.value]
  if (p) {
    movingMarker.setPosition(new window.AMap.LngLat(p.longitude, p.latitude))
  }
}

function focusStop(stop) {
  if (map && stop.longitude && stop.latitude) {
    map.setZoomAndCenter(16, new window.AMap.LngLat(stop.longitude, stop.latitude))
  }
}

// 监听播放速度变化
watch(playSpeed, () => {
  if (isPlaying.value) {
    stopPlay()
    startPlay()
  }
})
</script>

<style scoped>
/* 主布局 */
.track-content {
  display: grid;
  grid-template-columns: 1fr 320px;
  gap: 16px;
  height: calc(100vh - 132px);
  min-height: 500px;
}

/* 地图容器 */
.map-wrapper {
  position: relative;
  background: var(--bg-card);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
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

/* 悬浮筛选栏 - 左上角 */
.map-floating-bar {
  position: absolute;
  top: 16px;
  left: 16px;
  z-index: 200;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-radius: var(--radius-md);
  background: var(--bg-card);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid var(--border-color);
  box-shadow: var(--shadow-sm);
  flex-wrap: wrap;
}

/* 播放控制条 */
.playback-bar {
  position: absolute;
  bottom: 16px;
  left: 50%;
  transform: translateX(-50%);
  width: calc(100% - 32px);
  max-width: 600px;
  display: flex;
  align-items: center;
  padding: 12px 16px;
  background: rgba(28, 30, 46, 0.9);
  backdrop-filter: blur(12px);
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
  z-index: 100;
}

html:not(.dark) .playback-bar {
  background: rgba(255, 255, 255, 0.95);
  border: 1px solid rgba(0, 0, 0, 0.08);
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
  gap: 8px;
  font-weight: 600;
  font-size: 13px;
  flex-shrink: 0;
  color: var(--text-primary);
}

.panel-body {
  padding: 16px;
  overflow-y: auto;
}

.empty-state {
  align-items: center;
  justify-content: center;
  text-align: center;
  color: var(--text-secondary);
  padding: 60px 20px;
  gap: 12px;
}

/* 统计 */
.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  padding: 16px;
}

.stat-box {
  background: var(--surface-variant, rgba(255,255,255,0.03));
  padding: 14px;
  border-radius: 10px;
  text-align: center;
}

.stat-num {
  font-size: 22px;
  font-weight: 700;
}

.stat-label {
  font-size: 11px;
  color: var(--text-secondary);
  margin-top: 4px;
}

/* 停留点列表 */
.stops-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px;
}

.stop-item {
  padding: 12px;
  background: var(--surface-variant, rgba(255,255,255,0.03));
  border-radius: 8px;
  cursor: pointer;
  transition: var(--transition);
}

.stop-item:hover {
  background: rgba(79, 140, 255, 0.08);
}

.stop-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
}

.stop-meta {
  font-size: 11px;
  color: var(--text-secondary);
  margin-top: 4px;
}

/* 打卡记录列表 */
.checkins-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px;
}

.checkin-item {
  padding: 12px;
  background: var(--surface-variant, rgba(255,255,255,0.03));
  border-radius: 8px;
}

.checkin-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.checkin-time {
  font-size: 12px;
  color: var(--text-secondary);
}

.checkin-addr {
  font-size: 12px;
  color: var(--text-secondary);
  margin-top: 4px;
}
</style>
