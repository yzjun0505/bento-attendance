<template>
  <div class="page-container fade-in-up">
    <div class="page-header">
      <div>
        <h2 class="page-title">消息通知</h2>
        <p class="page-subtitle">管理系统通知消息</p>
      </div>
      <el-button type="primary" :icon="Promotion" @click="openSendDialog">发送通知</el-button>
    </div>

    <div class="filter-bar">
      <el-select v-model="filters.type" placeholder="消息类型" clearable style="width: 140px" @change="loadData">
        <el-option label="系统通知" value="system" />
        <el-option label="打卡通知" value="checkin" />
        <el-option label="项目通知" value="project" />
        <el-option label="告警通知" value="alert" />
      </el-select>
      <el-button type="primary" :icon="Search" @click="loadData">搜索</el-button>
    </div>

    <div class="table-card">
      <el-table
        :data="tableData"
        v-loading="loading"
        class="custom-table"
        style="width: 100%"
      >
        <el-table-column prop="title" label="标题" min-width="160" />
        <el-table-column prop="type" label="类型" width="120">
          <template #default="{ row }">
            <el-tag :type="typeTagMap[row.type]" size="small" effect="dark" round>
              {{ typeNameMap[row.type] }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="user_name" label="接收人" width="120">
          <template #default="{ row }">
            {{ row.user_name || '全部用户' }}
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" width="180">
          <template #default="{ row }">
            {{ formatTime(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column prop="is_read" label="状态" width="100">
          <template #default="{ row }">
            <el-tag v-if="row.is_read === 1" type="success" size="small" effect="plain" round>已读</el-tag>
            <el-tag v-else type="warning" size="small" effect="plain" round>未读</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <div class="table-actions">
              <el-button type="danger" text size="small" @click="handleDelete(row)">删除</el-button>
            </div>
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
          @size-change="loadData"
          @current-change="loadData"
        />
      </div>
    </div>

    <el-dialog
      v-model="sendDialogVisible"
      title="发送通知"
      width="520px"
      :close-on-click-modal="false"
    >
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
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { getAllNotifications, sendNotification, deleteNotification } from '@/api/notifications'
import { getUsers } from '@/api/users'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Promotion, Search } from '@element-plus/icons-vue'

const typeNameMap = { system: '系统通知', checkin: '打卡通知', project: '项目通知', alert: '告警通知' }
const typeTagMap = { system: '', checkin: 'success', project: 'warning', alert: 'danger' }

const loading = ref(false)
const sending = ref(false)
const tableData = ref([])
const userList = ref([])
const sendDialogVisible = ref(false)
const sendFormRef = ref(null)

const filters = reactive({ type: '' })
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })

const sendForm = reactive({
  title: '',
  content: '',
  type: 'system',
  user_id: null
})

const sendRules = {
  title: [{ required: true, message: '请输入标题', trigger: 'blur' }],
  content: [{ required: true, message: '请输入内容', trigger: 'blur' }],
  type: [{ required: true, message: '请选择类型', trigger: 'change' }]
}

onMounted(() => {
  loadData()
  loadUsers()
})

async function loadData() {
  loading.value = true
  try {
    const res = await getAllNotifications({ ...filters, ...pagination })
    tableData.value = res.data.list
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
    loadData()
  } catch (e) {
    console.error('发送通知失败:', e)
  } finally {
    sending.value = false
  }
}

async function handleDelete(row) {
  await ElMessageBox.confirm('确定删除该通知？', '警告', { type: 'warning' })
  try {
    await deleteNotification(row.id)
    ElMessage.success('删除成功')
    loadData()
  } catch (e) {
    console.error('删除通知失败:', e)
  }
}

function formatTime(val) {
  if (!val) return '—'
  const d = new Date(val)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}
</script>

<style scoped>
.table-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}
</style>
