using UnityEngine;

[ExecuteInEditMode]
public class RotationCamera : MonoBehaviour
{
    [SerializeField] private bool isRotate = true;
    [SerializeField] private float radius = 10.0f;
    [SerializeField] private float height = 5.0f;
    
    [SerializeField] private float angle = 5.0f;

    [SerializeField] private float rotateSpeed = 1;
    [SerializeField] private float upDownSpeed = 1;

    [SerializeField] private Vector3 center = new Vector3();

    void Start()
    {
    }

    private void OnGUI()
    {
//        Update();
    }

    // Update is called once per frame
    void Update()
    {
        if (!isRotate) return;

        var t = Time.time * 0.1f;
        var t2 = angle + t * rotateSpeed;
        var t3 = t * upDownSpeed;

        var x = radius * Mathf.Cos(t2);
        var z = radius * Mathf.Sin(t2);
        var y = height + height * Mathf.Sin(t3) * 0.5f;

        this.transform.position = new Vector3(x, y, z);

        this.transform.LookAt(center);
    }
}