@tool
extends EditorScript

func _run():
    # Get the EditorInterface singleton.
    var editor_interface = get_editor_interface()

    # Get the selection object from the editor interface.
    var selection = editor_interface.get_selection()

    # Get the list of currently selected nodes.
    var selected_nodes = selection.get_selected_nodes()

    # Check if there is at least one node selected.
    if selected_nodes.is_empty():
        print("No node is currently selected in the scene tree.")
        return

    # Get the first selected node.
    var selected_node = selected_nodes[0]

    # Print the tree of the selected node to the Output console.
    print("--- Printing tree for selected node: " + selected_node.name + " ---")
    selected_node.print_tree_pretty()
    print("---------------------------------------------")
