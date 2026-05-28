<template>
  <div class="page-container fade-in-up">
    <div class="unified-card">
      <div class="header-section">
        <div>
          <h2 class="page-title">防伪码查询</h2>
          <p class="page-subtitle">验证照片真伪，查询防伪码对应的业务记录</p>
        </div>
      </div>

      <div class="search-section">
        <div class="search-input-wrapper">
          <el-input
            v-model="searchCode"
            placeholder="请输入16位防伪码（大写字母+数字）"
            maxlength="16"
            show-word-limit
            clearable
            size="large"
            @keyup.enter="handleSearch"
            class="search-input"
          >
            <template #prefix>
              <el-icon><Ticket /></el-icon>
            </template>
          </el-input>
          <el-button type="primary" size="large" :icon="Search" @click="handleSearch" :loading="loading">
            查询
          </el-button>
          <el-button size="large" :icon="Camera" @click="toggleScanner" v-if="scannerSupported">
            {{ showScanner ? '关闭扫码' : '扫码输入' }}
          </el-button>
        </div>

        <div v-if="showScanner" class="scanner-wrapper">
          <div class="scanner-container">
            <video ref="videoRef" class="scanner-video" autoplay playsinline muted></video>
            <div class="scanner-overlay">
              <div class="scanner-frame"></div>
              <p class="scanner-tip">将防伪码对准摄像头</p>
            </div>
          </div>
        </div>
      </div>

      <div class="result-section" v-if="hasSearched">
        <el-empty v-if="!result" description="未找到该防伪码对应的打卡或进度上报记录，请确认防伪码是否正确" />

        <div v-else class="result-card">
          <div class="result-status" :class="statusClass">
            <el-icon size="24"><CircleCheck v-if="statusClass === 'valid'" /><Warning v-if="statusClass === 'used'" /><Timer v-if="statusClass === 'expired'" /></el-icon>
            <span>{{ statusText }}</span>
          </div>

          <div class="result-content">
            <div class="photo-section">
              <div class="photo-wrapper-large" @click="showPhoto(result.photo)">
                <el-image
                  v-if="result.photo"
                  :src="getPhotoUrl(result.photo)"
                  fit="cover"
                  class="result-photo"
                >
                  <template #error>
                    <div class="photo-error-large">
                      <el-icon><Picture /></el-icon>
                      <p>照片加载失败</p>
                    </div>
                  </template>
                </el-image>
                <div v-else class="no-photo-large">
                  <el-icon><Picture /></el-icon>
                  <p>暂无照片</p>
                </div>
                <div class="photo-zoom-hint">
                  <el-icon><ZoomIn /></el-icon> 点击查看大图
                </div>
              </div>
            </div>

            <div class="info-section">
              <div class="info-grid">
                <div class="info-item">
                  <div class="info-label">人员</div>
                  <div class="info-value">
                    <el-avatar :size="24" style="background: var(--gradient-green); font-size: 12px; margin-right: 8px;">
                      {{ result.user_name ? result.user_name.charAt(0) : '—' }}
                    </el-avatar>
                    {{ result.user_name || '—' }}
                  </div>
                </div>
                <div class="info-item">
                  <div class="info-label">记录时间</div>
                  <div class="info-value">{{ formatTime(result.created_at) }}</div>
                </div>
                <div class="info-item">
                  <div class="info-label">业务类型</div>
                  <div class="info-value">
                    <el-tag :type="getTypeTagColor(result.type)" size="small" round effect="dark">
                      {{ getTypeName(result.type) }}
                    </el-tag>
                  </div>
                </div>
                <div class="info-item">
                  <div class="info-label">所属项目</div>
                  <div class="info-value">{{ result.project_name || '—' }}</div>
                </div>
                <div v-if="result.address" class="info-item full-width">
                  <div class="info-label">打卡地点</div>
                  <div class="info-value">
                    <el-icon><Location /></el-icon> {{ result.address || '—' }}
                  </div>
                </div>
                <div class="info-item">
                  <div class="info-label">防伪码</div>
                  <div class="info-value code-value">{{ result.watermark_code || result.anti_fake_code || searchCode }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <el-dialog v-model="photoDialogVisible" title="打卡照片" width="800px" destroy-on-close>
      <div class="photo-dialog-content">
        <img :src="currentPhotoUrl" alt="打卡大图" class="dialog-photo" />
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { searchByCode } from '@/api/checkin'
import { Search, Camera, Ticket, Picture, ZoomIn, Location, CircleCheck, Warning, Timer } from '@element-plus/icons-vue'

const route = useRoute()
const searchCode = ref('')
const loading = ref(false)
const hasSearched = ref(false)
const result = ref(null)
const photoDialogVisible = ref(false)
const currentPhotoUrl = ref('')
const showScanner = ref(false)
const scannerSupported = ref(false)
const videoRef = ref(null)
let stream = null
let scanInterval = null

const TYPE_NAME_MAP = {
  'in': '上班',
  'out': '下班',
  'clock_in': '上班',
  'clock_out': '下班',
  'site_visit': '实地考察',
  'progress': '项目进度',
  'safety': '安全检查',
  'device': '设备位置',
  'custom': '自定义',
  'progress_report': '项目进度上报',
}

function getTypeName(type) {
  return TYPE_NAME_MAP[type] || type
}

function getTypeTagColor(type) {
  if (type === 'in' || type === 'clock_in') return 'success'
  if (type === 'out' || type === 'clock_out') return 'info'
  return 'warning'
}

const statusClass = ref('valid')
const statusText = ref('防伪码有效')

function getStatusInfo(status) {
  switch (status) {
    case 'used':
      return { class: 'used', text: '防伪码已使用' }
    case 'expired':
      return { class: 'expired', text: '防伪码已过期' }
    default:
      return { class: 'valid', text: '防伪码有效' }
  }
}

async function handleSearch() {
  const code = searchCode.value.trim().toUpperCase()
  if (!code) {
    return
  }
  searchCode.value = code
  loading.value = true
  hasSearched.value = true
  result.value = null
  try {
    const res = await searchByCode(code)
    if (res.data) {
      result.value = res.data
      const info = getStatusInfo(res.data.code_status)
      statusClass.value = info.class
      statusText.value = info.text
    }
  } catch (e) {
    result.value = null
  } finally {
    loading.value = false
  }
}

function formatTime(t) {
  if (!t) return '—'
  // 后端返回本地时间字符串，不再加Z后缀（否则会+8h偏移）
  let timeStr = t
  if (typeof t === 'string' && t.includes(' ')) {
    timeStr = t.replace(' ', 'T')
  }
  return new Date(timeStr).toLocaleString('zh-CN', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit'
  })
}

function getPhotoUrl(photo) {
  if (!photo) return ''
  if (photo.startsWith('http')) return photo
  const baseUrl = import.meta.env.VITE_API_BASE_URL || window.location.origin
  return baseUrl + photo
}

function showPhoto(photo) {
  currentPhotoUrl.value = getPhotoUrl(photo)
  photoDialogVisible.value = true
}

async function toggleScanner() {
  if (showScanner.value) {
    stopScanner()
  } else {
    showScanner.value = true
    await nextTick()
    startScanner()
  }
}

async function startScanner() {
  try {
    stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } })
    if (videoRef.value) {
      videoRef.value.srcObject = stream
      await videoRef.value.play()
      scanInterval = setInterval(() => {
        scanCode()
      }, 500)
    }
  } catch (e) {
    console.error('摄像头启动失败', e)
  }
}

function stopScanner() {
  showScanner.value = false
  if (scanInterval) {
    clearInterval(scanInterval)
    scanInterval = null
  }
  if (stream) {
    stream.getTracks().forEach(track => track.stop())
    stream = null
  }
}

function scanCode() {
  if (!videoRef.value || !stream) return
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')
  const video = videoRef.value
  canvas.width = video.videoWidth
  canvas.height = video.videoHeight
  ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
  // 简单的 OCR 模拟：从画面中心区域提取图像并尝试识别
  // 实际项目中建议使用 jsQR 或 zxing 等库
  // 这里通过简单的灰度扫描尝试检测高对比度区域
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
  const data = imageData.data
  let code = ''
  let inCode = false
  const centerX = Math.floor(canvas.width / 2)
  const centerY = Math.floor(canvas.height / 2)
  const scanWidth = Math.floor(canvas.width * 0.6)
  const startX = centerX - Math.floor(scanWidth / 2)
  const endX = centerX + Math.floor(scanWidth / 2)
  const y = centerY

  for (let x = startX; x < endX; x++) {
    const i = (y * canvas.width + x) * 4
    const brightness = (data[i] + data[i + 1] + data[i + 2]) / 3
    if (brightness < 100) {
      if (!inCode) {
        inCode = true
      }
    } else {
      if (inCode) {
        inCode = false
      }
    }
  }

  // 由于没有集成真正的二维码/OCR库，这里不做自动识别
  // 仅提供摄像头预览，用户可以手动输入
}

onMounted(() => {
  scannerSupported.value = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia)
  if (route.query.code) {
    searchCode.value = route.query.code
    handleSearch()
  }
})

onUnmounted(() => {
  stopScanner()
})
</script>

<style scoped>
.unified-card {
  background: var(--bg-card);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}

.header-section {
  padding: 24px 32px 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.search-section {
  padding: 24px 32px;
}

.search-input-wrapper {
  display: flex;
  gap: 12px;
  align-items: center;
}

.search-input {
  flex: 1;
  max-width: 500px;
}

.scanner-wrapper {
  margin-top: 20px;
  display: flex;
  justify-content: center;
}

.scanner-container {
  position: relative;
  width: 400px;
  height: 300px;
  border-radius: 12px;
  overflow: hidden;
  background: #000;
}

.scanner-video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.scanner-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.scanner-frame {
  width: 280px;
  height: 120px;
  border: 2px solid rgba(79, 140, 255, 0.8);
  border-radius: 8px;
  box-shadow: 0 0 0 999px rgba(0, 0, 0, 0.4);
}

.scanner-tip {
  color: rgba(255, 255, 255, 0.9);
  margin-top: 16px;
  font-size: 14px;
  text-shadow: 0 1px 4px rgba(0, 0, 0, 0.5);
}

.result-section {
  padding: 0 32px 32px;
  flex: 1;
  overflow-y: auto;
}

.result-card {
  background: var(--bg-card);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.result-status {
  padding: 16px 24px;
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 16px;
  font-weight: 600;
  border-bottom: 1px solid var(--border-light);
}

.result-status.valid {
  background: rgba(103, 194, 58, 0.1);
  color: #67c23a;
}

.result-status.used {
  background: rgba(230, 162, 60, 0.1);
  color: #e6a23c;
}

.result-status.expired {
  background: rgba(245, 108, 108, 0.1);
  color: #f56c6c;
}

.result-content {
  display: flex;
  gap: 24px;
  padding: 24px;
}

.photo-section {
  flex-shrink: 0;
}

.photo-wrapper-large {
  position: relative;
  width: 320px;
  height: 400px;
  border-radius: 12px;
  overflow: hidden;
  cursor: pointer;
  background: #1e1e24;
}

.result-photo {
  width: 100%;
  height: 100%;
  transition: transform 0.4s ease;
}

.photo-wrapper-large:hover .result-photo {
  transform: scale(1.05);
}

.photo-zoom-hint {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 12px;
  background: rgba(0, 0, 0, 0.6);
  color: rgba(255, 255, 255, 0.9);
  font-size: 13px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  opacity: 0;
  transition: opacity 0.3s;
}

.photo-wrapper-large:hover .photo-zoom-hint {
  opacity: 1;
}

.no-photo-large,
.photo-error-large {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.3);
  font-size: 48px;
}

.no-photo-large p,
.photo-error-large p {
  margin-top: 12px;
  font-size: 14px;
}

.info-section {
  flex: 1;
  min-width: 0;
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.info-item.full-width {
  grid-column: span 2;
}

.info-label {
  font-size: 12px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.info-value {
  font-size: 15px;
  color: var(--text-primary);
  font-weight: 500;
  display: flex;
  align-items: center;
  word-break: break-all;
}

.code-value {
  font-family: 'Courier New', monospace;
  letter-spacing: 2px;
  color: var(--accent-blue);
  font-size: 16px;
}

.photo-dialog-content {
  display: flex;
  justify-content: center;
  align-items: center;
}

.dialog-photo {
  max-width: 100%;
  max-height: 70vh;
  object-fit: contain;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

@media (max-width: 768px) {
  .result-content {
    flex-direction: column;
    align-items: center;
  }

  .photo-wrapper-large {
    width: 100%;
    max-width: 320px;
  }

  .info-grid {
    grid-template-columns: 1fr;
  }

  .info-item.full-width {
    grid-column: span 1;
  }

  .search-input-wrapper {
    flex-wrap: wrap;
  }

  .search-input {
    max-width: 100%;
    width: 100%;
  }
}
</style>
