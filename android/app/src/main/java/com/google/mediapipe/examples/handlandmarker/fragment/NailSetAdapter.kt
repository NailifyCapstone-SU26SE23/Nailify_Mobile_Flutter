package com.google.mediapipe.examples.handlandmarker.fragment

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.google.mediapipe.examples.handlandmarker.R
import com.google.mediapipe.examples.handlandmarker.databinding.ItemNailSetBinding
import com.google.mediapipe.examples.handlandmarker.model.NailSet
import java.text.NumberFormat
import java.util.Locale

class NailSetAdapter(
    private val onNailSetClick: (NailSet) -> Unit
) : ListAdapter<NailSet, NailSetAdapter.NailSetViewHolder>(NailSetDiffCallback) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): NailSetViewHolder {
        val binding = ItemNailSetBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return NailSetViewHolder(binding, onNailSetClick)
    }

    override fun onBindViewHolder(holder: NailSetViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    class NailSetViewHolder(
        private val binding: ItemNailSetBinding,
        private val onNailSetClick: (NailSet) -> Unit
    ) : RecyclerView.ViewHolder(binding.root) {
        fun bind(nailSet: NailSet) {
            val itemCount = nailSet.items.size
            val tagCount = nailSet.tags.size

            Glide.with(binding.nailSetImage)
                .load(nailSet.imageUrl)
                .placeholder(R.drawable.ic_baseline_photo_library_24)
                .error(R.drawable.ic_baseline_photo_library_24)
                .centerCrop()
                .into(binding.nailSetImage)
            binding.nailSetName.text = nailSet.name
            binding.nailSetStatus.text = if (nailSet.isActive) "Active" else "Inactive"
            binding.nailSetDescription.text = nailSet.description ?: "No description provided."
            binding.nailSetPrice.text = formatCurrency(nailSet.price)
            binding.nailSetItems.text = itemView.context.resources.getQuantityString(
                R.plurals.nail_set_item_count,
                itemCount,
                itemCount
            )
            binding.nailSetTags.text = itemView.context.resources.getQuantityString(
                R.plurals.nail_set_tag_count,
                tagCount,
                tagCount
            )
            binding.nailSetShape.text = nailSet.shape?.let { "Shape: $it" } ?: "No default shape"
            binding.root.setOnClickListener { onNailSetClick(nailSet) }
        }

        private fun formatCurrency(value: Double): String {
            return NumberFormat.getCurrencyInstance(Locale.US).format(value)
        }
    }

    private object NailSetDiffCallback : DiffUtil.ItemCallback<NailSet>() {
        override fun areItemsTheSame(oldItem: NailSet, newItem: NailSet): Boolean {
            return oldItem.id == newItem.id
        }

        override fun areContentsTheSame(oldItem: NailSet, newItem: NailSet): Boolean {
            return oldItem == newItem
        }
    }
}
