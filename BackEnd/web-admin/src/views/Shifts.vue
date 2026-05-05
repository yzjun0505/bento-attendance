<template>
  <div class="page-container fade-in-up">
    <div class="unified-card">
      <div class="header-section">
        <div>
          <h2 class="page-title">班次管理</h2>
          <p class="page-subtitle">管理考勤班次规则</p>
        </div>
        <el-button type="primary" :icon="Plus" @click="openDialog()">新增班次</el-button>
      </div>

      <div class="filter-section">
        <el-input
          v-model="filters.keyword"
          placeholder="搜索班次名称"
          :prefix-icon="Search"
          clearable
          style="width: 220px"
          @clear="loadData"
          @keyup.enter="loadData"
        />
        <el-button type="primary" :icon="Search" @click="loadData">搜索</el-button>
      </div>

      <div class="table-section">
        <el-table :data="tableData" v-loading="loading" class="custom-table" style="width: 100%">
        <el-table-column prop="name" label="班次名称" min-width="120" />
        <el-table-column prop="start_time" label="上班时间" width="100">
          <template #default="{ row }">{{ formatTime(row.start_time) }}</template>
        </el-table-column>
        <el-table-column prop="end_time" label="下班时间" width="100">
          <template #default="{ row }">{{ formatTime(row.end_time) }}</template>
        </el-table-column>
        <el-table-column prop="late_tolerance" label="迟到容忍" width="100">
          <template #default="{ row }">{{ row.late_tolerance }} 分钟</template>
        </el-table-column>
        <el-table-column prop="early_tolerance" label="早退容忍" width="100">
          <template #default="{ row }">{{ row.early_tolerance }} 分钟</template>
        </el-table-column>
        <el-table-column prop="color" label="颜色" width="80">
          <template #default="{ row }">
            <div style="display:flex;align-items:center;gap:6px">
              <span
                :style="{
                  display: 'inline-block',
                  width: '16px',
                  height: '16px',
                  borderRadius: '4px',
                  background: row.color || '#3B82F6'
                }"
              />
              <span style="font-size:12px;color:var(--text-secondary)">{{ row.color || '#3B82F6' }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="90">
          <template #default="{ row }">
            <el-tag v-if="row.status === 1" type="success" size="small" effect="dark" round>启用</el-tag>
            <el-tag v-else type="info" size="small" effect="dark" round>停用</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <div class="table-actions">
              <el-button type="primary" link :icon="Edit" @click="openDialog(row)" />
              <el-button type="danger" link :icon="Delete" @click="handleDelete(row)" />
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
  </div>

  <el-dialog
    v-model="dialogVisible"
      :title="editingItem ? '编辑班次' : '新增班次'"
      width="520px"
      :close-on-click-modal="false"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="班次名称" prop="name">
          <el-input v-model="form.name" placeholder="如：白班、夜班" />
        </el-form-item>
        <el-form-item label="上班时间" prop="start_time">
          <el-time-picker v-model="form.start_time" format="HH:mm" value-format="HH:mm" placeholder="选择上班时间" style="width: 100%" />
        </el-form-item>
        <el-form-item label="下班时间" prop="end_time">
          <el-time-picker v-model="form.end_time" format="HH:mm" value-format="HH:mm" placeholder="选择下班时间" style="width: 100%" />
        </el-form-item>
        <el-form-item label="迟到容忍">
          <el-input-number v-model="form.late_tolerance" :min="0" :max="120" :step="5" />
          <span style="margin-left: 8px; color: var(--text-secondary)">分钟</span>
        </el-form-item>
        <el-form-item label="早退容忍">
          <el-input-number v-model="form.early_tolerance" :min="0" :max="120" :step="5" />
          <span style="margin-left: 8px; color: var(--text-secondary)">分钟</span>
        </el-form-item>
        <el-form-item label="颜色标识">
          <el-color-picker v-model="form.color" show-alpha />
        </el-form-item>
        <el-form-item label="状态">
          <el-switch v-model="form.status" :active-value="1" :inactive-value="0" active-text="启用" inactive-text="停用" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { getShifts, createShift, updateShift, deleteShift } from '@/api/shifts'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Search, Edit, Delete } from '@element-plus/icons-vue'

const loading = ref(false)
const saving = ref(false)
const tableData = ref([])
const dialogVisible = ref(false)
const editingItem = ref(null)
const formRef = ref(null)

const filters = reactive({ keyword: '' })
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })

const form = reactive({
  name: '',
  start_time: '',
  end_time: '',
  late_tolerance: 15,
  early_tolerance: 15,
  color: '#3B82F6',
  status: 1
})

const rules = {
  name: [{ required: true, message: '请输入班次名称', trigger: 'blur' }],
  start_time: [{ required: true, message: '请选择上班时间', trigger: 'change' }],
  end_time: [{ required: true, message: '请选择下班时间', trigger: 'change' }]
}

onMounted(() => loadData())

async function loadData() {
  loading.value = true
  try {
    const res = await getShifts({ ...filters, ...pagination })
    tableData.value = res.data.list || res.data
    if (res.data.total !== undefined) pagination.total = res.data.total
  } catch (e) {
    console.error('加载班次列表失败:', e)
  } finally {
    loading.value = false
  }
}

function openDialog(item = null) {
  editingItem.value = item
  if (item) {
    Object.assign(form, {
      name: item.name,
      start_time: formatTime(item.start_time),
      end_time: formatTime(item.end_time),
      late_tolerance: item.late_tolerance ?? 15,
      early_tolerance: item.early_tolerance ?? 15,
      color: item.color || '#3B82F6',
      status: item.status ?? 1
    })
  } else {
    Object.assign(form, {
      name: '', start_time: '', end_time: '',
      late_tolerance: 15, early_tolerance: 15, color: '#3B82F6', status: 1
    })
  }
  dialogVisible.value = true
}

async function handleSave() {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  saving.value = true
  try {
    if (editingItem.value) {
      await updateShift(editingItem.value.id, { ...form })
      ElMessage.success('更新成功')
    } else {
      await createShift({ ...form })
      ElMessage.success('创建成功')
    }
    dialogVisible.value = false
    loadData()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '保存失败')
  } finally {
    saving.value = false
  }
}

async function handleDelete(row) {
  await ElMessageBox.confirm(`确定删除班次「${row.name}」？`, '警告', { type: 'warning' })
  try {
    await deleteShift(row.id)
    ElMessage.success('删除成功')
    loadData()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '删除失败')
  }
}

function formatTime(val) {
  if (!val) return '--:--'
  // 支持 "08:00:00" 和 "08:00" 两种格式
  const parts = String(val).split(':')
  return parts.length >= 2 ? `${parts[0]}:${parts[1]}` : val
}
</script>

<style scoped>
.table-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}
</style>
