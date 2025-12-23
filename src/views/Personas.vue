<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import axios from 'axios'
import Sortable from 'sortablejs'

interface Persona {
  id: string
  order: number
  name: string
  prompt: string
  isDefault?: boolean
}

const personas = ref<Persona[]>([])
const dialogVisible = ref(false)
const editingPersona = ref<Persona | null>(null)
const form = ref({ name: '', prompt: '' })
const loading = ref(false)
let sortableInstance: Sortable | null = null

async function loadPersonas() {
  try {
    const res = await axios.get('/api/personas')
    personas.value = res.data.sort((a: Persona, b: Persona) => a.order - b.order)
    await nextTick()
    initSortable()
  } catch {
    personas.value = [
      { id: 'default', order: 1, name: '默认助手', prompt: '你是一个友好的AI助手。', isDefault: true }
    ]
  }
}

function initSortable() {
  const tableBody = document.querySelector('.el-table__body-wrapper tbody')
  if (!tableBody || sortableInstance) return

  sortableInstance = Sortable.create(tableBody as HTMLElement, {
    animation: 150,
    handle: '.drag-handle',
    ghostClass: 'sortable-ghost',
    onEnd: async (evt) => {
      const { oldIndex, newIndex } = evt
      if (oldIndex === newIndex || oldIndex === undefined || newIndex === undefined) return

      // 更新本地顺序
      const movedItem = personas.value.splice(oldIndex, 1)[0]
      if (!movedItem) return
      personas.value.splice(newIndex, 0, movedItem)

      // 更新所有人格的序号
      try {
        const updates = personas.value.map((p, index) => ({
          id: p.id,
          order: index + 1
        }))

        // 批量更新序号
        for (const update of updates) {
          await axios.put(`/api/personas/${update.id}`, { order: update.order })
        }

        ElMessage.success('排序已更新')
        loadPersonas()
      } catch {
        ElMessage.error('排序更新失败')
        loadPersonas()
      }
    }
  })
}

function openDialog(persona?: Persona) {
  if (persona) {
    editingPersona.value = persona
    form.value = { name: persona.name, prompt: persona.prompt }
  } else {
    editingPersona.value = null
    form.value = { name: '', prompt: '' }
  }
  dialogVisible.value = true
}

async function savePersona() {
  if (!form.value.name || !form.value.prompt) {
    ElMessage.warning('请填写完整信息')
    return
  }
  loading.value = true
  try {
    if (editingPersona.value) {
      await axios.put(`/api/personas/${editingPersona.value.id}`, form.value)
      ElMessage.success('人格已更新')
    } else {
      await axios.post('/api/personas', form.value)
      ElMessage.success('人格已创建')
    }
    dialogVisible.value = false
    loadPersonas()
  } catch {
    ElMessage.error('保存失败')
  } finally {
    loading.value = false
  }
}

async function deletePersona(persona: Persona) {
  if (persona.isDefault) {
    ElMessage.warning('默认人格不能删除')
    return
  }
  try {
    await ElMessageBox.confirm(`确定删除人格「${persona.name}」吗？`, '确认删除')
    await axios.delete(`/api/personas/${persona.id}`)
    ElMessage.success('已删除')
    loadPersonas()
  } catch {}
}

async function setDefault(persona: Persona) {
  try {
    await axios.post(`/api/personas/${persona.id}/default`)
    ElMessage.success(`已将「${persona.name}」设为默认人格`)
    loadPersonas()
  } catch {
    ElMessage.error('设置失败')
  }
}


onMounted(loadPersonas)
</script>

<template>
  <div class="personas-page">
    <el-card shadow="hover">
      <template #header>
        <div class="header">
          <span>人格列表</span>
          <el-button type="primary" @click="openDialog()">
            <el-icon><Plus /></el-icon>
            新建人格
          </el-button>
        </div>
      </template>
      
      <el-table :data="personas" stripe row-key="id">
        <el-table-column label="" width="50" align="center">
          <template #default>
            <el-icon class="drag-handle" style="cursor: move; font-size: 18px;">
              <Rank />
            </el-icon>
          </template>
        </el-table-column>
        <el-table-column prop="order" label="序号" width="80" align="center" />
        <el-table-column prop="name" label="名称" width="150">
          <template #default="{ row }">
            {{ row.name }}
            <el-tag v-if="row.isDefault" size="small" type="success" style="margin-left: 8px">默认</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="prompt" label="提示词" show-overflow-tooltip />
        <el-table-column label="操作" width="220">
          <template #default="{ row }">
            <el-button size="small" @click="openDialog(row)">编辑</el-button>
            <el-button size="small" type="success" @click="setDefault(row)" :disabled="row.isDefault">设为默认</el-button>
            <el-button size="small" type="danger" @click="deletePersona(row)" :disabled="row.isDefault">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      
      <div class="tip">
        <div>💡 拖拽左侧图标可调整人格顺序</div>
        <div>用户使用 /person 序号 切换人格，如 /person 1</div>
      </div>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="editingPersona ? '编辑人格' : '新建人格'" width="500px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="名称">
          <el-input v-model="form.name" placeholder="如：猫娘、程序员助手" />
        </el-form-item>
        <el-form-item label="提示词">
          <el-input v-model="form.prompt" type="textarea" :rows="10" placeholder="描述这个人格的性格、说话风格等..." />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="loading" @click="savePersona">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script lang="ts">
import { Rank } from '@element-plus/icons-vue'
export default { components: { Rank } }
</script>

<style scoped>
.personas-page {
  height: 100%;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.tip {
  margin-top: 16px;
  color: #909399;
  font-size: 13px;
}

.tip > div {
  margin-bottom: 4px;
}

.sortable-ghost {
  opacity: 0.4;
  background: #f0f9ff;
}

.drag-handle {
  cursor: move;
  color: #909399;
  transition: color 0.3s;
}

.drag-handle:hover {
  color: #409eff;
}
</style>
