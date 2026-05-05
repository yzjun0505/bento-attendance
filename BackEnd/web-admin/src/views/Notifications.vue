<template>
  <div class="page-container fade-in-up">
    <div class="unified-card">
      <div class="header-section">
        <div>
          <h2 class="page-title">消息通知</h2>
          <p class="page-subtitle">管理通知消息与审批</p>
        </div>
        <el-button type="primary" :icon="Promotion" @click="openSendDialog">发送通知</el-button>
      </div>

    <el-tabs v-model="activeTab" class="notification-tabs">
      <!-- 通知公告 Tab -->
      <el-tab-pane label="通知公告" name="notifications">
        <div class="filter-section">
          <el-select v-model="filters.type" placeholder="消息类型" clearable style="width: 140px" @change="loadNotifications">
            <el-option label="系统通知" value="system" />
            <el-option label="打卡通知" value="checkin" />
            <el-option label="项目通知" value="project" />
            <el-option label="告警通知" value="alert" />
          </el-select>
          <el-button type="primary" :icon="Search" @click="loadNotifications">搜索</el-button>
        </div>

        <div class="table-section">
          <el-table :data="notificationData" v-loading="loading" class="custom-table" style="width: 100%">
            <el-table-column prop="title" label="标题" min-width="160" />
            <el-table-column prop="type" label="类型" width="120">
              <template #default="{ row }">
                <el-tag :type="typeTagMap[row.type]" size="small" effect="dark" round>{{ typeNameMap[row.type] }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="user_name" label="接收人" width="120">
              <template #default="{ row }">{{ row.user_name || '全部用户' }}</template>
            </el-table-column>
            <el-table-column prop="created_at" label="创建时间" width="180">
              <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
            </el-table-column>
            <el-table-column prop="is_read" label="状态" width="100">
              <template #default="{ row }">
                <el-tag v-if="row.is_read === 1" type="success" size="small" effect="plain" round>已读</el-tag>
                <el-tag v-else type="warning" size="small" effect="plain" round>未读</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="100" fixed="right">
              <template #default="{ row }">
                <el-button type="danger" text size="small" @click="handleDeleteNotification(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>

          <div style="padding: 16px; display: flex; justify-content: flex-end;">
            <el-pagination
              v-model:current-page="pagination.page"
              v-model:page-size="pagination.pageSize"
              :total="pagination.total"
              :page-sizes="[10, 20, 50]"
              layout="total, sizes, prev, pager, next"
              background
              @size-change="loadNotifications"
              @current-change="loadNotifications"
            />
          </div>
        </div>
      </el-tab-pane>

      <!-- 审批管理 Tab -->
      <el-tab-pane label="审批管理" name="approvals">
        <div class="filter-section">
          <el-select v-model="approvalFilters.status" placeholder="审批状态" clearable style="width: 130px" @change="loadApprovals">
            <el-option label="待审批" value="pending" />
            <el-option label="已通过" value="approved" />
            <el-option label="已驳回" value="rejected" />
          </el-select>
          <el-select v-model="approvalFilters.type" placeholder="审批类型" clearable style="width: 130px" @change="loadApprovals">
            <el-option label="请假" value="leave" />
            <el-option label="加班" value="overtime" />
          </el-select>
          <el-button type="primary" :icon="Search" @click="loadApprovals">搜索</el-button>
        </div>

        <div class="table-section">
          <el-table :data="approvalData" v-loading="approvalLoading" class="custom-table" style="width: 100%">
            <el-table-column prop="user_name" label="申请人" width="100" />
            <el-table-column prop="type" label="类型" width="100">
              <template #default="{ row }">
                <el-tag :type="row.type === 'leave' ? 'warning' : row.type === 'overtime' ? 'danger' : 'info'" size="small" effect="dark" round>
                  {{ row.type === 'leave' ? '请假' : row.type === 'overtime' ? '加班' : row.type }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="reason" label="原因" min-width="200" show-overflow-tooltip />
            <el-table-column prop="start_date" label="开始日期" width="120" />
            <el-table-column prop="end_date" label="结束日期" width="120">
              <template #default="{ row }">{{ row.end_date || '—' }}</template>
            </el-table-column>
            <el-table-column prop="status" label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="row.status === 'pending' ? 'warning' : row.status === 'approved' ? 'success' : 'danger'" size="small" effect="dark" round>
                  {{ row.status === 'pending' ? '待审批' : row.status === 'approved' ? '已通过' : '已驳回' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="created_at" label="申请时间" width="180">
              <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
            </el-table-column>
            <el-table-column label="操作" width="180" fixed="right">
              <template #default="{ row }">
                <div v-if="row.status === 'pending'" style="display:flex;gap:4px">
                  <el-button type="success" size="small" @click="openApprovalDialog(row, 'approve')">通过</el-button>
                  <el-button type="danger" size="small" @click="openApprovalDialog(row, 'reject')">驳回</el-button>
                </div>
                <span v-else style="color:var(--text-secondary);font-size:12px">
                  {{ row.remark || '—' }}
                </span>
              </template>
            </el-table-column>
          </el-table>

          <div style="padding: 16px; display: flex; justify-content: flex-end;">
            <el-pagination
              v-model:current-page="approvalPagination.page"
              v-model:page-size="approvalPagination.pageSize"
              :total="approvalPagination.total"
              :page-sizes="[10, 20, 50]"
              layout="total, sizes, prev, pager, next"
              background
              @size-change="loadApprovals"
              @current-change="loadApprovals"
            />
          </div>
        </div>
      </el-tab-pane>
    </el-tabs>
  </div>

  <!-- 发送通知弹窗 -->
    <el-dialog v-model="sendDialogVisible" title="发送通知" width="520px" :close-on-click-modal="false">
      <el-form ref="sendFormRef" :model="sendForm" :rules="sendRules" label-width="80px">
        <el-form-item label="标题" prop="title">
          <el-input v-model="sendForm.title" placeholder="请输入通知标题" />
        </el-form-item>
        <el-form-item label="内容" prop="content">
          <el-input v-model="sendForm.content" type="textarea" :rows="4" placeholder="请输入通知内容" />
        </el-form-item>
        <el-form-item label="类型" prop="type">
          <el-select v-model="sendForm.type" placeholder="请选择类型" style="width: 100%">
            <el-option label="系统通知" value="system" />
            <el-option label="打卡通知" value="checkin" />
            <el-option label="告警通知" value="alert" />
          </el-select>
        </el-form-item>
        <el-form-item label="接收对象" prop="user_id">
          <el-select v-model="sendForm.user_id" placeholder="请选择接收对象" clearable style="width: 100%">
            <el-option label="全部用户" :value="null" />
            <el-option v-for="u in userList" :key="u.id" :label="u.name" :value="u.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="sendDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="sending" @click="handleSend">发送</el-button>
      </template>
    </el-dialog>

    <!-- 审批弹窗 -->
    <el-dialog v-model="approvalDialogVisible" :title="approvalAction === 'approve' ? '审批通过' : '审批驳回'" width="420px" :close-on-click-modal="false">
      <el-form label-width="60px">
        <el-form-item label="备注">
          <el-input v-model="approvalRemark" type="textarea" :rows="3" :placeholder="approvalAction === 'approve' ? '审批通过备注（可选）' : '请填写驳回原因'" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="approvalDialogVisible = false">取消</el-button>
        <el-button :type="approvalAction === 'approve' ? 'success' : 'danger'" :loading="approvalSubmitting" @click="handleApprovalAction">
          {{ approvalAction === 'approve' ? '确认通过' : '确认驳回' }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, watch } from 'vue'
import { getAllNotifications, sendNotification, deleteNotification } from '@/api/notifications'
import { getApprovals, approveApproval, rejectApproval } from '@/api/approvals'
import { getUsers } from '@/api/users'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Promotion, Search } from '@element-plus/icons-vue'

const typeNameMap = { system: '系统通知', checkin: '打卡通知', project: '项目通知', alert: '告警通知' }
const typeTagMap = { system: '', checkin: 'success', project: 'warning', alert: 'danger' }

const activeTab = ref('notifications')
const loading = ref(false)
const sending = ref(false)
const notificationData = ref([])
const userList = ref([])
const sendDialogVisible = ref(false)
const sendFormRef = ref(null)

const filters = reactive({ type: '' })
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })

const sendForm = reactive({ title: '', content: '', type: 'system', user_id: null })
const sendRules = {
  title: [{ required: true, message: '请输入标题', trigger: 'blur' }],
  content: [{ required: true, message: '请输入内容', trigger: 'blur' }],
  type: [{ required: true, message: '请选择类型', trigger: 'change' }]
}

// 审批相关
const approvalLoading = ref(false)
const approvalData = ref([])
const approvalFilters = reactive({ status: '', type: '' })
const approvalPagination = reactive({ page: 1, pageSize: 20, total: 0 })
const approvalDialogVisible = ref(false)
const approvalSubmitting = ref(false)
const approvalAction = ref('approve')
const approvalRemark = ref('')
const currentApproval = ref(null)

onMounted(() => {
  loadNotifications()
  loadUsers()
})

watch(activeTab, (val) => {
  if (val === 'approvals') loadApprovals()
})

async function loadNotifications() {
  loading.value = true
  try {
    const res = await getAllNotifications({ ...filters, ...pagination })
    notificationData.value = res.data.list
    pagination.total = res.data.total
  } catch (e) {
    console.error('加载通知列表失败:', e)
  } finally {
    loading.value = false
  }
}

async function loadUsers() {
  try {
    const res = await getUsers({ pageSize: 999, status: 1 })
    userList.value = res.data.list
  } catch (e) {
    console.error('加载用户列表失败:', e)
  }
}

function openSendDialog() {
  Object.assign(sendForm, { title: '', content: '', type: 'system', user_id: null })
  sendDialogVisible.value = true
}

async function handleSend() {
  const valid = await sendFormRef.value?.validate().catch(() => false)
  if (!valid) return
  sending.value = true
  try {
    await sendNotification(sendForm)
    ElMessage.success('通知发送成功')
    sendDialogVisible.value = false
    loadNotifications()
  } catch (e) {
    console.error('发送通知失败:', e)
  } finally {
    sending.value = false
  }
}

async function handleDeleteNotification(row) {
  await ElMessageBox.confirm('确定删除该通知？', '警告', { type: 'warning' })
  try {
    await deleteNotification(row.id)
    ElMessage.success('删除成功')
    loadNotifications()
  } catch (e) {
    console.error('删除通知失败:', e)
  }
}

// 审批相关方法
async function loadApprovals() {
  approvalLoading.value = true
  try {
    const res = await getApprovals({ ...approvalFilters, ...approvalPagination })
    approvalData.value = res.data.list || res.data || []
    if (res.data.total !== undefined) approvalPagination.total = res.data.total
  } catch (e) {
    console.error('加载审批列表失败:', e)
  } finally {
    approvalLoading.value = false
  }
}

function openApprovalDialog(row, action) {
  currentApproval.value = row
  approvalAction.value = action
  approvalRemark.value = ''
  approvalDialogVisible.value = true
}

async function handleApprovalAction() {
  if (!currentApproval.value) return
  approvalSubmitting.value = true
  try {
    if (approvalAction.value === 'approve') {
      await approveApproval(currentApproval.value.id, approvalRemark.value)
      ElMessage.success('审批已通过，考勤记录已自动更新')
    } else {
      if (!approvalRemark.value.trim()) {
        ElMessage.warning('请填写驳回原因')
        approvalSubmitting.value = false
        return
      }
      await rejectApproval(currentApproval.value.id, approvalRemark.value)
      ElMessage.success('已驳回')
    }
    approvalDialogVisible.value = false
    loadApprovals()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '操作失败')
  } finally {
    approvalSubmitting.value = false
  }
}

function formatTime(val) {
  if (!val) return '—'
  // 后端返回本地时间字符串，替换空格为T确保浏览器按本地时间解析
  const d = new Date(typeof val === 'string' ? val.replace(' ', 'T') : val)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}
</script>

<style scoped>
.notification-tabs {
  margin-top: 8px;
}
.notification-tabs :deep(.el-tabs__header) {
  margin-bottom: 0;
}
</style>
