<template>
  <div class="app">
    <header>
      <h1>Projet Final - Gestion d'Items</h1>
    </header>
    <main>
      <div class="form-section">
        <h2>Créer un nouvel item</h2>
        <form @submit.prevent="createItem">
          <input
            v-model="newItem.name"
            type="text"
            placeholder="Nom"
            required
          />
          <textarea
            v-model="newItem.description"
            placeholder="Description"
            rows="3"
          ></textarea>
          <button type="submit">Créer</button>
        </form>
      </div>
      <div class="items-section">
        <h2>Liste des items</h2>
        <div v-if="loading" class="loading">Chargement...</div>
        <div v-else-if="error" class="error">{{ error }}</div>
        <div v-else-if="items.length === 0" class="empty">Aucun item</div>
        <div v-else class="items-list">
          <div v-for="item in items" :key="item.id" class="item">
            <div class="item-content">
              <h3>{{ item.name }}</h3>
              <p v-if="item.description">{{ item.description }}</p>
              <small>{{ formatDate(item.created_at) }}</small>
            </div>
            <button @click="deleteItem(item.id)" class="delete-btn">Supprimer</button>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script>
import axios from 'axios';

const API_BASE = '/api';

export default {
  name: 'App',
  data() {
    return {
      items: [],
      loading: false,
      error: null,
      newItem: {
        name: '',
        description: '',
      },
    };
  },
  mounted() {
    this.fetchItems();
  },
  methods: {
    async fetchItems() {
      this.loading = true;
      this.error = null;
      try {
        const response = await axios.get(`${API_BASE}/items`);
        this.items = response.data;
      } catch (err) {
        this.error = 'Erreur lors du chargement des items';
        console.error(err);
      } finally {
        this.loading = false;
      }
    },
    async createItem() {
      try {
        const response = await axios.post(`${API_BASE}/items`, this.newItem);
        this.items.unshift(response.data);
        this.newItem = { name: '', description: '' };
      } catch (err) {
        this.error = 'Erreur lors de la création';
        console.error(err);
      }
    },
    async deleteItem(id) {
      if (!confirm('Êtes-vous sûr de vouloir supprimer cet item ?')) {
        return;
      }
      try {
        await axios.delete(`${API_BASE}/items/${id}`);
        this.items = this.items.filter(item => item.id !== id);
      } catch (err) {
        this.error = 'Erreur lors de la suppression';
        console.error(err);
      }
    },
    formatDate(dateString) {
      return new Date(dateString).toLocaleString('fr-FR');
    },
  },
};
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background: #f5f5f5;
}

.app {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

header {
  background: #2c3e50;
  color: white;
  padding: 20px;
  border-radius: 8px;
  margin-bottom: 20px;
}

header h1 {
  font-size: 24px;
}

main {
  display: grid;
  gap: 20px;
}

.form-section,
.items-section {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

h2 {
  margin-bottom: 15px;
  color: #2c3e50;
}

form {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

input,
textarea {
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
}

button {
  padding: 10px 20px;
  background: #3498db;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

button:hover {
  background: #2980b9;
}

.items-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.item {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 15px;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: #fafafa;
}

.item-content {
  flex: 1;
}

.item h3 {
  margin-bottom: 5px;
  color: #2c3e50;
}

.item p {
  color: #666;
  margin-bottom: 5px;
}

.item small {
  color: #999;
  font-size: 12px;
}

.delete-btn {
  background: #e74c3c;
  padding: 8px 15px;
}

.delete-btn:hover {
  background: #c0392b;
}

.loading,
.error,
.empty {
  text-align: center;
  padding: 20px;
  color: #666;
}

.error {
  color: #e74c3c;
}
</style>

