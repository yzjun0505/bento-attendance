<template>
  <div class="page-container fade-in-up">
    <div class="unified-card">
      <div class="header-section">
        <div>
          <h2 class="page-title">节假日管理</h2>
          <p class="page-subtitle">管理法定节假日与调休</p>
        </div>
        <div style="display: flex; gap: 8px;">
          <el-button :icon="Upload" @click="batchDialogVisible = true">批量导入</el-button>
          <el-button type="primary" :icon="Plus" @click="openDialog()">新增节假日</el-button>
        </div>
      </div>

      <div class="filter-section">
        <el-date-picker
          v-model="selectedYear"
          type="year"
          placeholder="选择年份"
          format="YYYY年"
          value-format="YYYY"
          @change="loadData"
          style="width: 140px"
        />
        <el-select v-model="filters.type" placeholder="类型" clearable style="width: 130px" @change="loadData">
          <el-option label="放假" value="holiday" />
          <el-option label="调休上班" value="workday" />
        </el-select>
        <el-button type="primary" :icon="Search" @click="loadData">搜索</el-button>
      </div>

      <div class="table-section">
        <el-table :data="tableData" v-loading="loading" class="custom-table" style="width: 100%">
        <el-table-column prop="date" label="日期" width="130">
          <template #default="{ row }">
            <span style="font-weight:600">{{ row.date }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="名称" min-width="140" />
        <el-table-column prop="type" label="类型" width="120">
          <template #default="{ row }">
            <el-tag v-if="row.type === 'holiday'" type="success" size="small" effect="dark" round>放假</el-tag>
            <el-tag v-else-if="row.type === 'workday'" type="warning" size="small" effect="dark" round>调休上班</el-tag>
            <el-tag v-else type="info" size="small" effect="dark" round>{{ row.type }}</el-tag>
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
            :page-sizes="[10, 20, 50, 100]"
            layout="total, sizes, prev, pager, next"
            background
            @size-change="loadData"
            @current-change="loadData"
          />
        </div>
      </div>
    </div>

    <!-- 新增/编辑弹窗 -->
    <el-dialog v-model="dialogVisible" :title="editingItem ? '编辑节假日' : '新增节假日'" width="460px" :close-on-click-modal="false">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="80px">
        <el-form-item label="日期" prop="date">
          <el-date-picker v-model="form.date" type="date" placeholder="选择日期" value-format="YYYY-MM-DD" style="width: 100%" />
        </el-form-item>
        <el-form-item label="名称" prop="name">
          <el-input v-model="form.name" placeholder="如：元旦、春节" />
        </el-form-item>
        <el-form-item label="类型" prop="type">
          <el-select v-model="form.type" placeholder="选择类型" style="width: 100%">
            <el-option label="放假" value="holiday" />
            <el-option label="调休上班" value="workday" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>

    <!-- 批量导入弹窗 -->
    <el-dialog v-model="batchDialogVisible" title="批量导入节假日" width="520px" :close-on-click-modal="false">
      <el-alert title="格式说明" type="info" :closable="false" style="margin-bottom:16px">
        每行一条，格式：<code>日期 名称 类型</code><br />
        类型：<code>holiday</code>（放假）或 <code>workday</code>（调休上班）<br />
        示例：<code>2026-01-01 元旦 holiday</code>
      </el-alert>
      <el-input
        v-model="batchText"
        type="textarea"
        :rows="10"
        placeholder="2026-01-01 元旦 holiday
2026-01-02 元旦 holiday
2026-01-03 元旦 holiday
2026-02-07 春节调休 workday"
      />
      <template #footer>
        <el-button @click="batchDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="batchSaving" @click="handleBatchImport">导入</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { getHolidays, createHoliday, updateHoliday, deleteHoliday, batchCreateHolidays } from '@/api/holidays'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Search, Edit, Delete, Upload } from '@element-plus/icons-vue'

const loading = ref(false)
const saving = ref(false)
const batchSaving = ref(false)
const tableData = ref([])
const dialogVisible = ref(false)
const batchDialogVisible = ref(false)
const editingItem = ref(null)
const formRef = ref(null)
const batchText = ref('')

const selectedYear = ref(new Date().getFullYear().toString())
const filters = reactive({ type: '' })
const pagination = reactive({ page: 1, pageSize: 50, total: 0 })

const form = reactive({ date: '', name: '', type: 'holiday' })
const rules = {
  date: [{ required: true, message: '请选择日期', trigger: 'change' }],
  name: [{ required: true, message: '请输入名称', trigger: 'blur' }],
  type: [{ required: true, message: '请选择类型', trigger: 'change' }]
}

onMounted(() => loadData())

async function loadData() {
  loading.value = true
  try {
    const res = await getHolidays(selectedYear.value)
    let list = res.data.list || res.data || []
    if (filters.type) list = list.filter(h => h.type === filters.type)
    pagination.total = list.length
    // 简单前端分页
    const start = (pagination.page - 1) * pagination.pageSize
    tableData.value = list.slice(start, start + pagination.pageSize)
  } catch (e) {
    console.error('加载节假日失败:', e)
  } finally {
    loading.value = false
  }
}

function openDialog(item = null) {
  editingItem.value = item
  if (item) {
    Object.assign(form, { date: item.date, name: item.name, type: item.type })
  } else {
    Object.assign(form, { date: '', name: '', type: 'holiday' })
  }
  dialogVisible.value = true
}

async function handleSave() {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  saving.value = true
  try {
    if (editingItem.value) {
      await updateHoliday(editingItem.value.id, { ...form })
      ElMessage.success('更新成功')
    } else {
      await createHoliday({ ...form })
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
  await ElMessageBox.confirm(`确定删除「${row.name}」(${row.date})？`, '警告', { type: 'warning' })
  try {
    await deleteHoliday(row.id)
    ElMessage.success('删除成功')
    loadData()
  } catch (e) {
    ElMessage.error('删除失败')
  }
}

async function handleBatchImport() {
  const lines = batchText.value.trim().split('\n').filter(l => l.trim())
  if (lines.length === 0) return ElMessage.warning('请粘贴节假日数据')
  const items = []
  for (const line of lines) {
    const parts = line.trim().split(/\s+/)
    if (parts.length >= 3) {
      items.push({ date: parts[0], name: parts[1], type: parts[2] })
    }
  }
  if (items.length === 0) return ElMessage.warning('无法解析，请检查格式')
  batchSaving.value = true
  try {
    await batchCreateHolidays({ items })
    ElMessage.success(`成功导入 ${items.length} 条节假日`)
    batchDialogVisible.value = false
    batchText.value = ''
    loadData()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '导入失败')
  } finally {
    batchSaving.value = false
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
