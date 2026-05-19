<template>
  <teleport to="body">
    <div
      class="ai-avatar"
      :class="{ 'is-open': isOpen, 'is-dragging': dragging }"
      :style="{ left: `${position.x}px`, top: `${position.y}px` }"
      @pointerdown="startDrag"
    >
      <div class="ai-face">
        <span></span>
        <span></span>
      </div>
      <div class="ai-body"></div>
      <div class="ai-label">AI</div>
    </div>

    <section v-if="isOpen" class="ai-panel" :style="panelStyle">
      <header class="ai-panel-header">
        <div>
          <strong>境图 AI 助手</strong>
          <span>{{ aiModelEnabled ? '智能模型' : '本地数据模式' }}</span>
        </div>
        <div class="ai-header-actions">
          <el-button circle size="small" :icon="RefreshRight" @click="startNewChat" />
          <el-button circle size="small" :icon="Close" @click="isOpen = false" />
        </div>
      </header>

      <main ref="messageListRef" class="ai-messages">
        <div v-if="messages.length === 0" class="ai-welcome">
          <strong>今天想看哪块数据？</strong>
          <div class="ai-suggestions">
            <button v-for="item in suggestions" :key="item" @click="sendSuggestion(item)">
              {{ item }}
            </button>
          </div>
        </div>

        <article
          v-for="msg in messages"
          :key="msg.localId || msg.id"
          class="ai-message"
          :class="`is-${msg.role}`"
        >
          <div class="ai-bubble">
            <AiMarkdown :content="msg.content" />
            <AiResultRenderer
              v-if="msg.result"
              :result="msg.result"
              :confirming="confirmingActionId === msg.result.action?.id"
              @confirm-action="confirmAction"
            />
          </div>
        </article>

        <article v-if="loading" class="ai-message is-assistant">
          <div class="ai-bubble ai-loading">
            <span></span>
            <span></span>
            <span></span>
          </div>
        </article>
      </main>

      <footer class="ai-input-wrap">
        <el-input
          v-model="input"
          type="textarea"
          :rows="2"
          resize="none"
          placeholder="问我考勤、项目、审批或报表"
          @keydown.enter.exact.prevent="sendMessage()"
        />
        <el-button type="primary" :icon="Promotion" :loading="loading" @click="sendMessage">
          发送
        </el-button>
      </footer>
    </section>
  </teleport>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Close, Promotion, RefreshRight } from '@element-plus/icons-vue'
import AiMarkdown from './AiMarkdown.vue'
import AiResultRenderer from './AiResultRenderer.vue'
import { confirmAiAction, downloadAiReport, getAiSuggestions, sendAiMessage } from '@/api/ai'

const route = useRoute()
const isOpen = ref(false)
const dragging = ref(false)
const wasDragged = ref(false)
const loading = ref(false)
const aiModelEnabled = ref(false)
const input = ref('')
const conversationId = ref(null)
const messages = ref([])
const suggestions = ref([])
const confirmingActionId = ref(null)
const messageListRef = ref(null)

const position = ref(loadPosition())
let dragStart = null

const panelStyle = computed(() => {
  const width = Math.min(480, window.innerWidth - 24)
  const preferLeft = position.value.x > window.innerWidth / 2
  const left = preferLeft
    ? Math.max(12, position.value.x - width - 18)
    : Math.min(window.innerWidth - width - 12, position.value.x + 74)
  const top = Math.min(Math.max(12, position.value.y - 230), window.innerHeight - 620)
  return {
    width: `${width}px`,
    left: `${left}px`,
    top: `${Math.max(12, top)}px`
  }
})

function loadPosition() {
  try {
    const saved = JSON.parse(localStorage.getItem('ai-assistant-position') || 'null')
    if (saved && Number.isFinite(saved.x) && Number.isFinite(saved.y)) return saved
  } catch (_) {}
  return { x: window.innerWidth - 92, y: window.innerHeight - 150 }
}

function persistPosition() {
  localStorage.setItem('ai-assistant-position', JSON.stringify(position.value))
}

function clampPosition(x, y) {
  return {
    x: Math.min(Math.max(12, x), window.innerWidth - 72),
    y: Math.min(Math.max(84, y), window.innerHeight - 84)
  }
}

function startDrag(event) {
  if (event.button !== 0) return
  event.preventDefault()
  dragging.value = true
  wasDragged.value = false
  dragStart = {
    pointerId: event.pointerId,
    startX: event.clientX,
    startY: event.clientY,
    originX: position.value.x,
    originY: position.value.y
  }
  window.addEventListener('pointermove', moveDrag)
  window.addEventListener('pointerup', endDrag)
}

function moveDrag(event) {
  if (!dragStart) return
  const dx = event.clientX - dragStart.startX
  const dy = event.clientY - dragStart.startY
  if (Math.abs(dx) + Math.abs(dy) > 5) wasDragged.value = true
  position.value = clampPosition(dragStart.originX + dx, dragStart.originY + dy)
}

function endDrag() {
  dragging.value = false
  window.removeEventListener('pointermove', moveDrag)
  window.removeEventListener('pointerup', endDrag)
  persistPosition()
  if (!wasDragged.value) {
    isOpen.value = !isOpen.value
  }
  dragStart = null
}

function startNewChat() {
  conversationId.value = null
  messages.value = []
  input.value = ''
}

function currentContext() {
  return {
    page: route.path.replace('/', '') || 'dashboard',
    title: route.meta?.title || ''
  }
}

async function loadSuggestions() {
  try {
    const res = await getAiSuggestions(currentContext())
    suggestions.value = res.data || []
  } catch (_) {
    suggestions.value = ['今天管理摘要', '本周异常打卡统计', '有哪些待审批申请？']
  }
}

function sendSuggestion(text) {
  input.value = text
  sendMessage()
}

async function sendMessage() {
  const text = input.value.trim()
  if (!text || loading.value) return

  input.value = ''
  const userMessage = {
    localId: `user-${Date.now()}`,
    role: 'user',
    content: text
  }
  messages.value.push(userMessage)
  loading.value = true
  scrollToBottom()

  try {
    const res = await sendAiMessage({
      conversationId: conversationId.value,
      message: text,
      context: currentContext()
    })
    const data = res.data
    conversationId.value = data.conversationId
    aiModelEnabled.value = data.aiModelEnabled
    messages.value.push({
      localId: `assistant-${Date.now()}`,
      role: 'assistant',
      content: data.message,
      result: data.result
    })
  } catch (err) {
    messages.value.push({
      localId: `assistant-error-${Date.now()}`,
      role: 'assistant',
      content: err.message || 'AI 助手暂时不可用'
    })
  } finally {
    loading.value = false
    scrollToBottom()
  }
}

async function confirmAction(action) {
  confirmingActionId.value = action.id
  try {
    const res = await confirmAiAction(action.id)
    const result = res.data?.result
    if (result?.url) {
      const blob = await downloadAiReport(result.url)
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.download = 'attendance-report.xlsx'
      link.click()
      URL.revokeObjectURL(link.href)
    }
    ElMessage.success(res.message || result?.message || '操作已完成')
  } catch (err) {
    ElMessage.error(err.message || '操作确认失败')
  } finally {
    confirmingActionId.value = null
  }
}

function scrollToBottom() {
  nextTick(() => {
    if (messageListRef.value) {
      messageListRef.value.scrollTop = messageListRef.value.scrollHeight
    }
  })
}

function handleResize() {
  position.value = clampPosition(position.value.x, position.value.y)
  persistPosition()
}

watch(() => route.path, loadSuggestions)

onMounted(() => {
  loadSuggestions()
  window.addEventListener('resize', handleResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  window.removeEventListener('pointermove', moveDrag)
  window.removeEventListener('pointerup', endDrag)
})
</script>

<style scoped>
.ai-avatar {
  position: fixed;
  z-index: 2200;
  width: 62px;
  height: 72px;
  cursor: grab;
  user-select: none;
  touch-action: none;
  filter: drop-shadow(0 18px 32px rgba(0, 0, 0, 0.22));
  transition: transform 0.18s ease, filter 0.18s ease;
}

.ai-avatar.is-open,
.ai-avatar:hover {
  transform: translateY(-2px) scale(1.03);
}

.ai-avatar.is-dragging {
  cursor: grabbing;
  transition: none;
}

.ai-face {
  width: 54px;
  height: 48px;
  margin: 0 auto;
  border-radius: 18px 18px 16px 16px;
  background: linear-gradient(145deg, #ffffff, #dbeafe);
  border: 2px solid rgba(59, 130, 246, 0.45);
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 10px;
  position: relative;
}

.ai-face::before {
  content: '';
  position: absolute;
  top: -8px;
  width: 16px;
  height: 8px;
  border-radius: 10px 10px 0 0;
  background: #3b82f6;
}

.ai-face span {
  width: 7px;
  height: 10px;
  border-radius: 999px;
  background: #1d4ed8;
  box-shadow: 0 0 12px rgba(29, 78, 216, 0.5);
}

.ai-body {
  width: 42px;
  height: 28px;
  margin: -3px auto 0;
  border-radius: 10px 10px 18px 18px;
  background: linear-gradient(135deg, #3b82f6, #10b981);
  border: 1px solid rgba(255, 255, 255, 0.55);
}

.ai-label {
  position: absolute;
  right: -2px;
  bottom: 10px;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #0f172a;
  color: #ffffff;
  font-size: 11px;
  font-weight: 800;
  border: 2px solid #ffffff;
}

.ai-panel {
  position: fixed;
  z-index: 2190;
  height: min(620px, calc(100vh - 24px));
  background: rgba(18, 20, 31, 0.92);
  color: var(--text-primary);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 14px;
  box-shadow: 0 24px 80px rgba(0, 0, 0, 0.42);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

html:not(.dark) .ai-panel {
  background: rgba(255, 255, 255, 0.95);
  border-color: rgba(15, 23, 42, 0.1);
}

.ai-panel-header {
  height: 58px;
  padding: 12px 14px;
  border-bottom: 1px solid var(--border-color);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.ai-panel-header strong {
  display: block;
  font-size: 15px;
}

.ai-panel-header span {
  color: var(--text-secondary);
  font-size: 12px;
}

.ai-header-actions {
  display: flex;
  gap: 8px;
}

.ai-messages {
  flex: 1;
  overflow-y: auto;
  padding: 14px;
}

.ai-welcome {
  display: flex;
  flex-direction: column;
  gap: 12px;
  color: var(--text-primary);
}

.ai-welcome strong {
  font-size: 18px;
}

.ai-suggestions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.ai-suggestions button {
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: rgba(59, 130, 246, 0.08);
  color: var(--text-primary);
  padding: 8px 10px;
  cursor: pointer;
  font-size: 12px;
}

.ai-message {
  display: flex;
  margin-bottom: 12px;
}

.ai-message.is-user {
  justify-content: flex-end;
}

.ai-bubble {
  max-width: 92%;
  border-radius: 12px;
  padding: 10px 12px;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid var(--border-color);
}

.ai-message.is-user .ai-bubble {
  background: linear-gradient(135deg, #2563eb, #0f766e);
  border-color: transparent;
  color: #ffffff;
}

.ai-loading {
  display: flex;
  gap: 5px;
  align-items: center;
  width: 58px;
}

.ai-loading span {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--accent-blue);
  animation: ai-pulse 1s infinite ease-in-out;
}

.ai-loading span:nth-child(2) {
  animation-delay: 0.15s;
}

.ai-loading span:nth-child(3) {
  animation-delay: 0.3s;
}

.ai-input-wrap {
  border-top: 1px solid var(--border-color);
  padding: 12px;
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 10px;
}

@keyframes ai-pulse {
  0%, 80%, 100% { opacity: 0.35; transform: translateY(0); }
  40% { opacity: 1; transform: translateY(-3px); }
}

@media (max-width: 640px) {
  .ai-panel {
    left: 12px !important;
    right: 12px;
    top: 12px !important;
    width: auto !important;
    height: calc(100vh - 104px);
  }
}
</style>
