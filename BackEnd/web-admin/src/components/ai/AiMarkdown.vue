<template>
  <div class="ai-markdown">
    <template v-for="(block, index) in blocks" :key="index">
      <ul v-if="block.type === 'list'">
        <li v-for="(item, itemIndex) in block.items" :key="itemIndex">
          <template v-for="(part, partIndex) in inlineParts(item)" :key="partIndex">
            <strong v-if="part.bold">{{ part.text }}</strong>
            <span v-else>{{ part.text }}</span>
          </template>
        </li>
      </ul>
      <p v-else>
        <template v-for="(part, partIndex) in inlineParts(block.text)" :key="partIndex">
          <strong v-if="part.bold">{{ part.text }}</strong>
          <span v-else>{{ part.text }}</span>
        </template>
      </p>
    </template>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  content: {
    type: String,
    default: ''
  }
})

const blocks = computed(() => {
  const lines = props.content
    .replace(/\r/g, '')
    .split('\n')
    .map((line) => line.trim())

  const result = []
  let list = []

  function flushList() {
    if (list.length) {
      result.push({ type: 'list', items: list })
      list = []
    }
  }

  for (const line of lines) {
    if (!line) {
      flushList()
      continue
    }
    const itemMatch = line.match(/^[-*]\s+(.+)$/)
    if (itemMatch) {
      list.push(itemMatch[1])
      continue
    }
    flushList()
    result.push({ type: 'paragraph', text: line })
  }
  flushList()
  return result.length ? result : [{ type: 'paragraph', text: props.content }]
})

function inlineParts(text) {
  const parts = []
  const pattern = /\*\*(.+?)\*\*/g
  let lastIndex = 0
  let match
  while ((match = pattern.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push({ text: text.slice(lastIndex, match.index), bold: false })
    }
    parts.push({ text: match[1], bold: true })
    lastIndex = match.index + match[0].length
  }
  if (lastIndex < text.length) {
    parts.push({ text: text.slice(lastIndex), bold: false })
  }
  return parts
}
</script>

<style scoped>
.ai-markdown {
  display: flex;
  flex-direction: column;
  gap: 8px;
  line-height: 1.65;
  font-size: 13px;
}

.ai-markdown p {
  margin: 0;
}

.ai-markdown ul {
  margin: 0;
  padding-left: 18px;
}

.ai-markdown li + li {
  margin-top: 4px;
}

.ai-markdown strong {
  font-weight: 700;
  color: inherit;
}
</style>
