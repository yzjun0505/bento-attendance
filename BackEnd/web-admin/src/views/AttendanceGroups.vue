<template>
  <div class="page-container fade-in-up">
    <div class="page-header">
      <div>
        <h2 class="page-title">考勤组设置</h2>
        <p class="page-subtitle">管理考勤组规则与成员分配</p>
      </div>
      <el-button type="primary" :icon="Plus" @click="openDrawer()">新增考勤组</el-button>
    </div>

    <div class="filter-bar">
      <el-input
        v-model="filters.keyword"
        placeholder="搜索考勤组名称"
        :prefix-icon="Search"
        clearable
        style="width: 240px"
        @clear="loadData"
        @keyup.enter="loadData"
      />
      <el-select v-model="filters.status" placeholder="状态" clearable style="width: 120px" @change="loadData">
        <el-option label="启用" :value="1" />
        <el-option label="停用" :value="0" />
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
        <el-table-column prop="name" label="考勤组名称" min-width="140" />
        <el-table-column prop="start_time" label="上班时间" width="120">
          <template #default="{ row }">
            {{ formatTime(row.start_time) }}
          </template>
        </el-table-column>
        <el-table-column prop="end_time" label="下班时间" width="120">
          <template #default="{ row }">
            {{ formatTime(row.end_time) }}
          </template>
        </el-table-column>
        <el-table-column prop="late_tolerance" label="迟到容忍(分钟)" width="140">
          <template #default="{ row }">
            {{ row.late_tolerance || 0 }}
          </template>
        </el-table-column>
        <el-table-column prop="project_name" label="绑定项目" min-width="140">
          <template #default="{ row }">
            {{ row.project_name || '—' }}
          </template>
        </el-table-column>
        <el-table-column prop="member_count" label="成员数" width="90">
          <template #default="{ row }">
            {{ row.member_count || 0 }}
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-switch
              :model-value="row.status === 1"
              @change="(val) => handleToggleStatus(row, val)"
              active-text="启用"
              inactive-text="停用"
              inline-prompt
            />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <div class="table-actions">
              <el-button type="primary" text size="small" @click="openDrawer(row)">编辑</el-button>
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

    <el-drawer
      v-model="drawerVisible"
      :title="editingGroup ? '编辑考勤组' : '新增考勤组'"
      size="480px"
      :close-on-click-modal="false"
    >
      <el-form ref="drawerFormRef" :model="drawerForm" :rules="drawerRules" label-width="120px">
        <el-form-item label="考勤组名称" prop="name">
          <el-input v-model="drawerForm.name" placeholder="请输入考勤组名称" />
        </el-form-item>
        <el-form-item label="上班时间" prop="start_time">
          <el-time-picker
            v-model="drawerForm.start_time"
            format="HH:mm"
            value-format="HH:mm:ss"
            placeholder="选择上班时间"
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="下班时间" prop="end_time">
          <el-time-picker
            v-model="drawerForm.end_time"
            format="HH:mm"
            value-format="HH:mm:ss"
            placeholder="选择下班时间"
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="允许迟到分钟数" prop="late_tolerance">
          <el-input-number v-model="drawerForm.late_tolerance" :min="0" :max="120" style="width: 100%" />
        </el-form-item>
        <el-form-item label="绑定项目">
          <el-select v-model="drawerForm.project_id" placeholder="请选择项目" clearable style="width: 100%">
            <el-option v-for="p in projectList" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="成员选择">
          <el-select
            v-model="drawerForm.user_ids"
            multiple
            filterable
            placeholder="请选择成员"
            style="width: 100%"
          >
            <el-option v-for="u in userList" :key="u.id" :label="`${u.name}（${u.username}）`" :value="u.id" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="editingGroup" label="状态">
          <el-switch v-model="drawerForm.status" :active-value="1" :inactive-value="0" active-text="启用" inactive-text="停用" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="drawerVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-drawer>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import {
  getAttendanceGroups,
  getAttendanceGroupById,
  createAttendanceGroup,
  updateAttendanceGroup,
  deleteAttendanceGroup
} from '@/api/attendanceGroup'
import { getAllProjects } from '@/api/projects'
import { getUsers } from '@/api/users'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Search } from '@element-plus/icons-vue'

const loading = ref(false)
const saving = ref(false)
const tableData = ref([])
const projectList = ref([])
const userList = ref([])
const drawerVisible = ref(false)
const editingGroup = ref(null)
const drawerFormRef = ref(null)

const filters = reactive({ keyword: '', status: '' })
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })

const drawerForm = reactive({
  name: '',
  start_time: null,
  end_time: null,
  late_tolerance: 0,
  project_id: null,
  user_ids: [],
  status: 1
})

const drawerRules = {
  name: [{ required: true, message: '请输入考勤组名称', trigger: 'blur' }],
  start_time: [{ required: true, message: '请选择上班时间', trigger: 'change' }],
  end_time: [{ required: true, message: '请选择下班时间', trigger: 'change' }]
}

onMounted(() => {
  loadData()
  loadProjects()
  loadUsers()
})

async function loadData() {
  loading.value = true
  try {
    const res = await getAttendanceGroups({ ...filters, ...pagination })
    tableData.value = res.data.list
    pagination.total = res.data.total
  } catch (e) {
    console.error('加载考勤组失败:', e)
  } finally {
    loading.value = false
  }
}

async function loadProjects() {
  try {
    const res = await getAllProjects()
    projectList.value = res.data
  } catch (e) {
    console.error('加载项目列表失败:', e)
  }
}

async function loadUsers() {
  try {
    const res = await getUsers({ pageSize: 999 })
    userList.value = res.data.list
  } catch (e) {
    console.error('加载用户列表失败:', e)
  }
}

function formatTime(val) {
  if (!val) return '—'
  if (typeof val === 'string') {
    return val.substring(0, 5)
  }
  return val
}

async function openDrawer(group = null) {
  editingGroup.value = group
  if (group) {
    const res = await getAttendanceGroupById(group.id)
    const detail = res.data
    Object.assign(drawerForm, {
      name: detail.name,
      start_time: detail.start_time,
      end_time: detail.end_time,
      late_tolerance: detail.late_tolerance || 0,
      project_id: detail.project_id,
      user_ids: (detail.members || []).map(m => m.user_id),
      status: detail.status
    })
  } else {
    Object.assign(drawerForm, {
      name: '',
      start_time: null,
      end_time: null,
      late_tolerance: 0,
      project_id: null,
      user_ids: [],
      status: 1
    })
  }
  drawerVisible.value = true
}

async function handleSave() {
  const valid = await drawerFormRef.value?.validate().catch(() => false)
  if (!valid) return

  saving.value = true
  try {
    if (editingGroup.value) {
      const { user_ids, ...data } = drawerForm
      await updateAttendanceGroup(editingGroup.value.id, data)
      if (user_ids && user_ids.length > 0) {
        const { addGroupMembers } = await import('@/api/attendanceGroup')
        await addGroupMembers(editingGroup.value.id, user_ids)
      }
      ElMessage.success('更新成功')
    } else {
      await createAttendanceGroup(drawerForm)
      ElMessage.success('创建成功')
    }
    drawerVisible.value = false
    loadData()
  } catch (e) {
    console.error('保存考勤组失败:', e)
  } finally {
    saving.value = false
  }
}

async function handleToggleStatus(row, val) {
  try {
    await updateAttendanceGroup(row.id, { status: val ? 1 : 0 })
    ElMessage.success(val ? '已启用' : '已停用')
    loadData()
  } catch (e) {
    console.error('切换状态失败:', e)
  }
}

async function handleDelete(row) {
  await ElMessageBox.confirm(`确定删除考勤组「${row.name}」？`, '警告', { type: 'warning' })
  try {
    await deleteAttendanceGroup(row.id)
    ElMessage.success('删除成功')
    loadData()
  } catch (e) {
    console.error('删除考勤组失败:', e)
  }
}
</script>

<style scoped>
.table-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}
</style>
