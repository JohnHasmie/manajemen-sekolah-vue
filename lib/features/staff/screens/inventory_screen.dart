// School inventory management screen for staff.
// Like `pages/staff/Inventory.vue` in a Vue app.
//
// Displays a list of school assets/items with their condition status.
// Currently uses dummy data; in production this would call a Laravel
// `InventoryController@index` API endpoint.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/data/data_dummy.dart';

/// Lists all school inventory items with quantity and condition badges.
///
/// StatelessWidget -- no mutable state. In Vue terms, a presentational
/// component. The FAB (FloatingActionButton) is like a Vue `<button @click>`
/// that would open an "Add Item" form.
class InventarisScreen extends StatelessWidget {

  const InventarisScreen({super.key});

  /// Builds the main scaffold with inventory list and a FAB for adding items.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventaris')),
      body: ListView.builder(
        itemCount: DataDummy.inventory.length,
        itemBuilder: (context, index) {
          final item = DataDummy.inventory[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              leading: Icon(Icons.inventory_2, color: Colors.blue),
              title: Text(item['nama']),
              subtitle: Text('Jumlah: ${item['jumlah']}'),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item['kondisi'] == 'Baik' ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item['kondisi'],
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
    );
  }
}